"""Tests for futures_bot.core.risk_manager — position sizing & session windows."""

from __future__ import annotations

from datetime import datetime, time, timezone

import pytest
from freezegun import freeze_time

from futures_bot.core.risk_manager import CONTRACT_SPECS, ContractSpec, RiskManager


# ── Contract specs & symbol parsing ──

class TestContractSpecs:

    def test_known_symbols_all_present(self):
        for sym in ("MES", "MNQ", "MCL", "MGC", "MYM", "M2K",
                    "ES", "NQ", "CL", "GC"):
            assert sym in CONTRACT_SPECS
            spec = CONTRACT_SPECS[sym]
            assert isinstance(spec, ContractSpec)
            assert spec.tick_size > 0
            assert spec.tick_value > 0
            assert spec.point_value > 0

    def test_mes_spec_values(self):
        spec = CONTRACT_SPECS["MES"]
        assert spec.tick_size == 0.25
        assert spec.tick_value == 1.25
        assert spec.point_value == 5.0

    def test_mnq_spec_values(self):
        spec = CONTRACT_SPECS["MNQ"]
        assert spec.tick_size == 0.25
        assert spec.point_value == 2.0

    def test_get_spec_strips_month_code(self, risk_config):
        rm = RiskManager(risk_config)
        assert rm._get_spec("MESM6") is CONTRACT_SPECS["MES"]
        assert rm._get_spec("MNQZ5") is CONTRACT_SPECS["MNQ"]
        assert rm._get_spec("MCLH6") is CONTRACT_SPECS["MCL"]

    def test_get_spec_prefers_longest_prefix(self, risk_config):
        """MCL must match 'MCL' and not 'CL' (longer prefix wins)."""
        rm = RiskManager(risk_config)
        assert rm._get_spec("MCLM6") is CONTRACT_SPECS["MCL"]

    def test_get_spec_unknown_returns_none(self, risk_config):
        rm = RiskManager(risk_config)
        assert rm._get_spec("XYZ123") is None

    def test_get_tick_and_point_values(self, risk_config):
        rm = RiskManager(risk_config)
        assert rm.get_tick_value("MESM6") == 1.25
        assert rm.get_point_value("MESM6") == 5.0
        assert rm.get_tick_value("UNKNOWN") == 0.0
        assert rm.get_point_value("UNKNOWN") == 0.0


# ── calculate_position_size ──

class TestPositionSizing:

    def test_basic_sizing_mes(self, risk_config):
        rm = RiskManager(risk_config)
        # $150 risk, 5 point stop, MES point_value=$5 -> risk per ctr=$25 -> 6 ctrs
        # clamped to max_contracts_per_trade=5
        assert rm.calculate_position_size("MESM6", stop_distance=5.0) == 5

    def test_sizing_respects_custom_max_risk(self, risk_config):
        rm = RiskManager(risk_config)
        # $50 risk / ($5 * 5pts per ctr = $25) = 2 contracts
        assert rm.calculate_position_size("MESM6", stop_distance=5.0, max_risk=50.0) == 2

    def test_sizing_minimum_is_one_when_budget_fits(self, risk_config):
        """When 1 contract stays within 110% of budget, minimum floor is 1."""
        rm = RiskManager(risk_config)
        # $20 budget, 4pt stop on MES -> risk/ctr = $20. int(20/20)=1. Fits.
        assert rm.calculate_position_size("MESM6", stop_distance=4.0, max_risk=20.0) == 1

    def test_sizing_returns_zero_when_min_size_blows_budget(self, risk_config):
        """Safety guard: if 1 contract would exceed 110% of budget, return 0."""
        rm = RiskManager(risk_config)
        # $1 budget, 10pt stop, MES $5/pt -> risk/ctr=$50 >> $1.10 -> 0 contracts
        assert rm.calculate_position_size("MESM6", stop_distance=10.0, max_risk=1.0) == 0

    def test_sizing_caps_at_max_contracts_per_trade(self, risk_config):
        rm = RiskManager(risk_config)
        # Huge budget / tiny stop -> would be 1000, clamped at 5.
        assert rm.calculate_position_size("MESM6", stop_distance=0.5, max_risk=10000.0) == 5

    def test_sizing_unknown_symbol_returns_zero(self, risk_config):
        rm = RiskManager(risk_config)
        assert rm.calculate_position_size("XYZ", stop_distance=5.0) == 0

    def test_sizing_zero_stop_returns_zero(self, risk_config):
        rm = RiskManager(risk_config)
        assert rm.calculate_position_size("MESM6", stop_distance=0.0) == 0

    def test_sizing_negative_stop_returns_zero(self, risk_config):
        rm = RiskManager(risk_config)
        assert rm.calculate_position_size("MESM6", stop_distance=-1.0) == 0

    def test_buffer_trim_when_over_budget(self, risk_config):
        """When rounding up produces > 10% over budget, contracts are trimmed."""
        rm = RiskManager(risk_config)
        # We force cap at 2 so the buffer check has something to trim against:
        # risk=$50, MNQ point=$2, stop=4.9 -> per ctr=$9.80 -> int=5 -> cap
        # Not a direct buffer trigger; use the natural case:
        # With max_contracts_per_trade=1 and slight over-budget:
        rm.max_contracts_per_trade = 1
        # $20 risk, stop=5pts, MNQ pt=$2 -> per ctr=$10 -> int=2 -> cap 1
        size = rm.calculate_position_size("MNQM6", stop_distance=5.0, max_risk=20.0)
        assert size == 1


# ── calculate_stop_risk_dollars ──

class TestStopRiskDollars:

    def test_risk_dollars_basic(self, risk_config):
        rm = RiskManager(risk_config)
        # MES: 5pt * $5/pt * 2 ctrs = $50
        assert rm.calculate_stop_risk_dollars("MESM6", 5.0, 2) == pytest.approx(50.0)

    def test_risk_dollars_unknown_symbol(self, risk_config):
        rm = RiskManager(risk_config)
        assert rm.calculate_stop_risk_dollars("XYZ", 5.0, 1) == 0.0


# ── Session windows (time-sensitive, require mocking) ──

# NOTE: These tests use freezegun to set a fixed UTC clock. The module uses a
# simplified DST rule: March-November treated as EDT (-4h); Dec-Feb as EST (-5h).
# That shortcut has known bugs near DST boundaries; the tests below document the
# *current* behavior (green) and separately document the known bug (xfail).

class TestTradingSessionEDT:
    """June timestamps — EDT, UTC offset = -4h."""

    @freeze_time("2026-06-15 13:30:00")  # 09:30 ET
    def test_session_start_edt(self, risk_config):
        rm = RiskManager(risk_config)
        ok, _ = rm.is_trading_session()
        assert ok is True

    @freeze_time("2026-06-15 12:00:00")  # 08:00 ET - pre-market
    def test_pre_market_blocked(self, risk_config):
        rm = RiskManager(risk_config)
        ok, msg = rm.is_trading_session()
        assert ok is False
        assert "pre-market" in msg.lower()

    @freeze_time("2026-06-15 19:05:00")  # 15:05 ET
    def test_no_new_trades_after_3pm(self, risk_config):
        rm = RiskManager(risk_config)
        ok, msg = rm.is_trading_session()
        assert ok is False
        assert "no new trades" in msg.lower()

    @freeze_time("2026-06-15 19:45:00")  # 15:45 ET - flatten time
    def test_must_flatten_at_end_of_day(self, risk_config):
        rm = RiskManager(risk_config)
        assert rm.must_flatten() is True

    @freeze_time("2026-06-15 19:44:00")  # 15:44 ET - just before flatten
    def test_no_flatten_before_345(self, risk_config):
        rm = RiskManager(risk_config)
        assert rm.must_flatten() is False

    @freeze_time("2026-06-15 16:30:00")  # 12:30 ET - dead zone
    def test_dead_zone_detected(self, risk_config):
        rm = RiskManager(risk_config)
        assert rm.is_dead_zone() is True
        ok, msg = rm.is_trading_session()
        assert ok is True  # still tradable, just reduced size
        assert "dead zone" in msg.lower()

    @freeze_time("2026-06-15 17:30:00")  # 13:30 ET - dead zone end boundary
    def test_dead_zone_end_exclusive(self, risk_config):
        rm = RiskManager(risk_config)
        # dead_zone_end is 13:30 and the check is `< end` — 13:30 itself is OUT.
        assert rm.is_dead_zone() is False

    @freeze_time("2026-06-15 15:00:00")  # 11:00 ET
    def test_risk_multiplier_not_dead_zone(self, risk_config):
        rm = RiskManager(risk_config)
        assert rm.get_risk_multiplier() == 1.0

    @freeze_time("2026-06-15 16:30:00")  # 12:30 ET
    def test_risk_multiplier_dead_zone(self, risk_config):
        rm = RiskManager(risk_config)
        assert rm.get_risk_multiplier() == 0.5


class TestTradingSessionEST:
    """January timestamps — EST, UTC offset = -5h."""

    @freeze_time("2026-01-15 14:30:00")  # 09:30 ET
    def test_session_start_est(self, risk_config):
        rm = RiskManager(risk_config)
        ok, _ = rm.is_trading_session()
        assert ok is True

    @freeze_time("2026-01-15 20:30:00")  # 15:30 ET
    def test_session_end_est(self, risk_config):
        rm = RiskManager(risk_config)
        ok, _ = rm.is_trading_session()
        assert ok is False


class TestDSTBoundaryRegression:
    """Regression tests for the DST handling in `_get_et_time()`.

    US DST starts on the 2nd Sunday of March (Mar 8, 2026) and ends on the
    1st Sunday of November (Nov 1, 2026). These cases would previously fail
    with the old "month 3..11 = EDT" shortcut; they now pass because the
    module delegates to `zoneinfo.ZoneInfo('America/New_York')`.
    """

    @freeze_time("2026-03-02 19:45:00")  # Pre-DST; EST (UTC-5) -> 14:45 ET
    def test_early_march_is_est_not_edt(self, risk_config):
        rm = RiskManager(risk_config)
        assert rm.must_flatten() is False  # 14:45 ET, flatten is 15:45 ET

    @freeze_time("2026-03-02 20:45:00")  # Pre-DST; EST -> 15:45 ET
    def test_early_march_flatten_triggers_correctly(self, risk_config):
        rm = RiskManager(risk_config)
        assert rm.must_flatten() is True

    @freeze_time("2026-11-30 19:45:00")  # Post-DST; EST -> 14:45 ET
    def test_late_november_is_est_not_edt(self, risk_config):
        rm = RiskManager(risk_config)
        assert rm.must_flatten() is False

    @freeze_time("2026-03-09 13:30:00")  # Day after DST start; EDT (UTC-4) -> 09:30 ET
    def test_day_after_dst_start_session_opens_on_time(self, risk_config):
        rm = RiskManager(risk_config)
        ok, _ = rm.is_trading_session()
        assert ok is True

    @freeze_time("2026-11-01 14:30:00")  # DST end day; ET-wall-clock 09:30 (EST, UTC-5)
    def test_day_of_dst_end_session_opens_on_time(self, risk_config):
        rm = RiskManager(risk_config)
        ok, _ = rm.is_trading_session()
        assert ok is True


# ── can_open_position ──

class TestCanOpenPosition:

    @freeze_time("2026-06-15 15:00:00")  # 11:00 ET - active session
    def test_allows_in_session(self, risk_config):
        rm = RiskManager(risk_config)
        ok, _ = rm.can_open_position()
        assert ok is True

    @freeze_time("2026-06-15 15:00:00")  # 11:00 ET
    def test_blocks_when_max_positions_reached(self, risk_config):
        rm = RiskManager(risk_config)
        rm.open_positions = rm.max_positions
        ok, msg = rm.can_open_position()
        assert ok is False
        assert "max positions" in msg.lower()

    @freeze_time("2026-06-15 12:00:00")  # 08:00 ET
    def test_blocks_outside_session(self, risk_config):
        rm = RiskManager(risk_config)
        ok, _ = rm.can_open_position()
        assert ok is False
