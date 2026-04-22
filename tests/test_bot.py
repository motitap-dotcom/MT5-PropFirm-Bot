"""Tests for futures_bot.bot — pure helpers and trade execution guards.

Focus:
  - _load_config: file loading + missing-file fallback
  - _to_bar: dict -> VWAPBar conversion
  - _get_sleep_seconds: timeframe -> sleep mapping
  - _execute_trade: 5 pre-trade safety guards and bracket placement
  - _verify_bracket_orders: missing SL -> emergency SL -> close-position fallback
  - _process_fills: deduplication + guardian accounting
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock

import pytest

from futures_bot import bot as bot_mod
from futures_bot.bot import FuturesBot
from futures_bot.core.guardian import Guardian
from futures_bot.core.risk_manager import RiskManager


@pytest.fixture(autouse=True)
def _no_real_sleep(monkeypatch):
    """Short-circuit asyncio.sleep in bot.py so tests don't wait seconds."""

    async def _instant(_seconds, *_args, **_kwargs):
        return None

    monkeypatch.setattr(bot_mod.asyncio, "sleep", _instant)


# ── Test helpers / doubles ──

class _Sig(Enum):
    NONE = 0
    LONG = 1
    SHORT = 2


@dataclass
class _VWAPSetup:
    signal: _Sig
    entry_price: float
    stop_loss: float
    take_profit_1: float
    take_profit_2: float


@dataclass
class _ORBSetup:
    signal: _Sig
    entry_price: float
    stop_loss: float
    take_profit: float


def _make_bot_with_fakes(guardian_config, risk_config) -> FuturesBot:
    """Construct a bot with its external collaborators replaced by AsyncMocks."""
    bot = FuturesBot.__new__(FuturesBot)  # bypass __init__
    bot.config = {}
    bot.running = False
    bot.symbols = ["MESM6"]
    bot.timeframe = "5min"
    bot.current_day = "2026-04-22"
    bot.positions = []
    bot.vwap_strategies = {}
    bot.orb_strategies = {}
    bot.active_strategy = {"MESM6": "vwap"}
    bot._last_bar_time = {}
    bot._processed_fills = set()

    bot.guardian = Guardian(guardian_config)
    bot.risk_mgr = RiskManager(risk_config)

    # Fakes
    bot.client = AsyncMock()
    bot.client.place_market_order = AsyncMock(return_value={"orderId": 123})
    bot.client.place_stop_order = AsyncMock(return_value={"orderId": 124})
    bot.client.place_limit_order = AsyncMock(return_value={"orderId": 125})
    bot.client.get_open_orders = AsyncMock(return_value=[])
    bot.client.close_position = AsyncMock()
    bot.client.get_positions = AsyncMock(return_value=[])
    bot.client.get_contract_by_id = AsyncMock(return_value={"name": "MESM6"})

    bot.notifier = AsyncMock()
    bot.news_filter = MagicMock()
    bot.news_filter.is_restricted = MagicMock(return_value=(False, None))
    bot.news_filter.must_flatten_for_event = MagicMock(return_value=(False, None))
    bot.status_writer = MagicMock()
    return bot


# ── Pure helpers ──

class TestPureHelpers:

    def test_load_config_valid_file(self, tmp_path):
        cfg = tmp_path / "bot.json"
        cfg.write_text('{"symbols": ["MESM6"], "timeframe": "5min"}')
        bot = FuturesBot.__new__(FuturesBot)
        result = bot._load_config(str(cfg))
        assert result["symbols"] == ["MESM6"]

    def test_load_config_missing_file_returns_empty(self, tmp_path):
        bot = FuturesBot.__new__(FuturesBot)
        result = bot._load_config(str(tmp_path / "does_not_exist.json"))
        assert result == {}

    def test_to_bar_maps_all_fields(self):
        bot = FuturesBot.__new__(FuturesBot)
        bar = bot._to_bar({
            "timestamp": "2026-04-22T10:00:00Z",
            "open": 4500.0,
            "high": 4510.0,
            "low": 4495.0,
            "close": 4505.0,
            "volume": 1000,
        })
        assert bar.open == 4500.0
        assert bar.high == 4510.0
        assert bar.low == 4495.0
        assert bar.close == 4505.0
        assert bar.volume == 1000

    def test_to_bar_missing_fields_default_to_zero(self):
        bot = FuturesBot.__new__(FuturesBot)
        bar = bot._to_bar({})
        assert bar.open == 0
        assert bar.high == 0
        assert bar.close == 0
        assert bar.volume == 0

    def test_get_sleep_seconds_maps_timeframes(self):
        bot = FuturesBot.__new__(FuturesBot)
        bot.timeframe = "1min"
        assert bot._get_sleep_seconds() == 60
        bot.timeframe = "5min"
        assert bot._get_sleep_seconds() == 300
        bot.timeframe = "15min"
        assert bot._get_sleep_seconds() == 900

    def test_get_sleep_seconds_unknown_defaults_to_five_min(self):
        bot = FuturesBot.__new__(FuturesBot)
        bot.timeframe = "weird"
        assert bot._get_sleep_seconds() == 300


# ── _execute_trade safety guards ──

# freeze_time to get inside trading session for guards that depend on it.
from freezegun import freeze_time


@freeze_time("2026-06-15 15:00:00")  # 11:00 ET - session active, no dead zone
class TestExecuteTradeGuards:

    async def test_blocks_when_guardian_halted(self, guardian_config, risk_config):
        bot = _make_bot_with_fakes(guardian_config, risk_config)
        bot.guardian.update_balance(48400.0)  # HALTED
        setup = _VWAPSetup(_Sig.LONG, 4500.0, 4490.0, 4505.0, 4510.0)
        await bot._execute_trade("MESM6", setup, "VWAP")
        bot.client.place_market_order.assert_not_called()

    async def test_blocks_when_risk_mgr_says_no(self, guardian_config, risk_config):
        bot = _make_bot_with_fakes(guardian_config, risk_config)
        bot.risk_mgr.open_positions = bot.risk_mgr.max_positions
        setup = _VWAPSetup(_Sig.LONG, 4500.0, 4490.0, 4505.0, 4510.0)
        await bot._execute_trade("MESM6", setup, "VWAP")
        bot.client.place_market_order.assert_not_called()

    async def test_blocks_on_news_restriction(self, guardian_config, risk_config):
        bot = _make_bot_with_fakes(guardian_config, risk_config)
        bot.news_filter.is_restricted.return_value = (True, "CPI")
        setup = _VWAPSetup(_Sig.LONG, 4500.0, 4490.0, 4505.0, 4510.0)
        await bot._execute_trade("MESM6", setup, "VWAP")
        bot.client.place_market_order.assert_not_called()

    async def test_blocks_when_sl_equals_zero(self, guardian_config, risk_config):
        bot = _make_bot_with_fakes(guardian_config, risk_config)
        setup = _VWAPSetup(_Sig.LONG, 4500.0, 0.0, 4505.0, 4510.0)
        await bot._execute_trade("MESM6", setup, "VWAP")
        bot.client.place_market_order.assert_not_called()

    async def test_blocks_when_tp_equals_zero(self, guardian_config, risk_config):
        bot = _make_bot_with_fakes(guardian_config, risk_config)
        setup = _VWAPSetup(_Sig.LONG, 4500.0, 4490.0, 0.0, 4510.0)
        await bot._execute_trade("MESM6", setup, "VWAP")
        bot.client.place_market_order.assert_not_called()

    async def test_blocks_long_with_sl_above_entry(self, guardian_config, risk_config):
        """LONG trade where SL >= entry is nonsensical — must be blocked."""
        bot = _make_bot_with_fakes(guardian_config, risk_config)
        setup = _VWAPSetup(_Sig.LONG, 4500.0, 4510.0, 4520.0, 4530.0)
        await bot._execute_trade("MESM6", setup, "VWAP")
        bot.client.place_market_order.assert_not_called()

    async def test_blocks_short_with_sl_below_entry(self, guardian_config, risk_config):
        bot = _make_bot_with_fakes(guardian_config, risk_config)
        setup = _VWAPSetup(_Sig.SHORT, 4500.0, 4490.0, 4480.0, 4470.0)
        await bot._execute_trade("MESM6", setup, "VWAP")
        bot.client.place_market_order.assert_not_called()

    async def test_places_order_when_all_guards_pass(self, guardian_config, risk_config):
        bot = _make_bot_with_fakes(guardian_config, risk_config)
        # Pre-populate get_open_orders so bracket verification finds both SL and TP
        bot.client.get_open_orders.return_value = [
            {"action": "Sell", "orderType": "Stop"},
            {"action": "Sell", "orderType": "Limit"},
        ]
        setup = _VWAPSetup(_Sig.LONG, 4500.0, 4490.0, 4505.0, 4510.0)
        await bot._execute_trade("MESM6", setup, "VWAP")
        bot.client.place_market_order.assert_called_once()
        call_kwargs = bot.client.place_market_order.call_args.kwargs
        assert call_kwargs["symbol"] == "MESM6"
        assert call_kwargs["action"] == "Buy"
        assert call_kwargs["bracket"]["stopLoss"] == 4490.0
        assert call_kwargs["bracket"]["takeProfit"] == 4505.0  # VWAP uses tp1
        # Trade should be accounted for
        assert bot.risk_mgr.open_positions == 1

    async def test_uses_take_profit_for_orb_setup(self, guardian_config, risk_config):
        bot = _make_bot_with_fakes(guardian_config, risk_config)
        bot.client.get_open_orders.return_value = [
            {"action": "Sell", "orderType": "Stop"},
            {"action": "Sell", "orderType": "Limit"},
        ]
        setup = _ORBSetup(_Sig.LONG, 4500.0, 4490.0, 4520.0)  # no tp1
        await bot._execute_trade("MESM6", setup, "ORB")
        call_kwargs = bot.client.place_market_order.call_args.kwargs
        assert call_kwargs["bracket"]["takeProfit"] == 4520.0


# ── _verify_bracket_orders: emergency logic ──

@freeze_time("2026-06-15 15:00:00")
class TestVerifyBracketOrders:

    async def test_sl_and_tp_present_no_action(self, guardian_config, risk_config):
        bot = _make_bot_with_fakes(guardian_config, risk_config)
        bot.client.get_open_orders.return_value = [
            {"action": "Sell", "orderType": "Stop"},
            {"action": "Sell", "orderType": "Limit"},
        ]
        await bot._verify_bracket_orders("MESM6", "Buy", 1, 4490.0, 4510.0)
        bot.client.place_stop_order.assert_not_called()
        bot.client.place_limit_order.assert_not_called()
        bot.client.close_position.assert_not_called()

    async def test_missing_sl_placed_as_emergency(self, guardian_config, risk_config):
        bot = _make_bot_with_fakes(guardian_config, risk_config)
        bot.client.get_open_orders.return_value = [
            {"action": "Sell", "orderType": "Limit"},  # only TP exists
        ]
        await bot._verify_bracket_orders("MESM6", "Buy", 1, 4490.0, 4510.0)
        bot.client.place_stop_order.assert_called_once_with("MESM6", "Sell", 1, 4490.0)
        bot.client.close_position.assert_not_called()

    async def test_missing_sl_placement_fails_closes_position(self, guardian_config, risk_config):
        bot = _make_bot_with_fakes(guardian_config, risk_config)
        bot.client.get_open_orders.return_value = []  # no SL, no TP
        bot.client.place_stop_order.side_effect = RuntimeError("broker rejected")
        await bot._verify_bracket_orders("MESM6", "Buy", 1, 4490.0, 4510.0)
        bot.client.close_position.assert_called_once_with("MESM6")
        bot.notifier.guardian_alert.assert_called_once()

    async def test_missing_tp_placed_but_not_fatal(self, guardian_config, risk_config):
        bot = _make_bot_with_fakes(guardian_config, risk_config)
        bot.client.get_open_orders.return_value = [
            {"action": "Sell", "orderType": "Stop"},  # SL present, no TP
        ]
        await bot._verify_bracket_orders("MESM6", "Buy", 1, 4490.0, 4510.0)
        bot.client.place_limit_order.assert_called_once_with("MESM6", "Sell", 1, 4510.0)
        bot.client.close_position.assert_not_called()

    async def test_short_position_uses_buy_exits(self, guardian_config, risk_config):
        bot = _make_bot_with_fakes(guardian_config, risk_config)
        bot.client.get_open_orders.return_value = [
            {"action": "Buy", "orderType": "Stop"},
            {"action": "Buy", "orderType": "Limit"},
        ]
        await bot._verify_bracket_orders("MESM6", "Sell", 1, 4510.0, 4490.0)
        bot.client.place_stop_order.assert_not_called()

    async def test_wrong_action_does_not_count_as_bracket(self, guardian_config, risk_config):
        """An opposite-action Stop on the same symbol shouldn't satisfy SL check."""
        bot = _make_bot_with_fakes(guardian_config, risk_config)
        bot.client.get_open_orders.return_value = [
            {"action": "Buy", "orderType": "Stop"},  # wrong side for LONG exit
        ]
        await bot._verify_bracket_orders("MESM6", "Buy", 1, 4490.0, 4510.0)
        bot.client.place_stop_order.assert_called_once()


# ── _process_fills accounting ──

class TestProcessFills:

    async def test_dedupes_fills_by_id(self, guardian_config, risk_config):
        bot = _make_bot_with_fakes(guardian_config, risk_config)
        bot.vwap_strategies = {"MESM6": MagicMock()}
        fills = [{"id": 1, "pnl": 50.0, "action": "Sell", "qty": 1, "price": 4500}]
        await bot._process_fills(fills)
        await bot._process_fills(fills)  # replay
        assert bot.guardian.daily_pnl == 50.0  # not doubled
        assert bot.guardian.daily_trades == 1

    async def test_zero_pnl_fills_not_counted_as_close(self, guardian_config, risk_config):
        """Opening fills have pnl=0; they should NOT be recorded as trades."""
        bot = _make_bot_with_fakes(guardian_config, risk_config)
        bot.vwap_strategies = {"MESM6": MagicMock()}
        fills = [{"id": 1, "pnl": 0, "action": "Buy", "qty": 1, "price": 4500}]
        await bot._process_fills(fills)
        assert bot.guardian.daily_pnl == 0.0
        assert bot.guardian.daily_trades == 0

    async def test_negative_pnl_flagged_as_loss(self, guardian_config, risk_config):
        bot = _make_bot_with_fakes(guardian_config, risk_config)
        strat = MagicMock()
        bot.vwap_strategies = {"MESM6": strat}
        fills = [{"id": 1, "pnl": -75.0, "action": "Sell", "qty": 1, "price": 4490}]
        await bot._process_fills(fills)
        strat.record_trade_result.assert_called_once_with(False)

    async def test_positive_pnl_flagged_as_win(self, guardian_config, risk_config):
        bot = _make_bot_with_fakes(guardian_config, risk_config)
        strat = MagicMock()
        bot.vwap_strategies = {"MESM6": strat}
        fills = [{"id": 1, "pnl": 120.0, "action": "Sell", "qty": 1, "price": 4510}]
        await bot._process_fills(fills)
        strat.record_trade_result.assert_called_once_with(True)
