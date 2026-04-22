"""Tests for futures_bot.strategies.orb_breakout."""

from __future__ import annotations

import pytest

from futures_bot.strategies.orb_breakout import Bar, ORBBreakout, Signal


def _bar(close: float, *, high: float = None, low: float = None,
         open_: float = None, volume: float = 1000.0, timestamp: str = "t") -> Bar:
    return Bar(
        timestamp=timestamp,
        open=open_ if open_ is not None else close,
        high=high if high is not None else close,
        low=low if low is not None else close,
        close=close,
        volume=volume,
    )


# ── Range building ──

class TestRangeBuilding:

    def test_initial_state(self, orb_config):
        orb = ORBBreakout(orb_config)
        assert orb._orb_high is None
        assert orb._orb_low is None
        assert orb.get_range() is None

    def test_single_bar_sets_high_low(self, orb_config):
        orb = ORBBreakout(orb_config)
        orb.on_bar(_bar(100.0, high=101.0, low=99.0), is_orb_period=True)
        assert orb._orb_high == 101.0
        assert orb._orb_low == 99.0

    def test_multiple_bars_track_extremes(self, orb_config):
        orb = ORBBreakout(orb_config)
        orb.on_bar(_bar(100.0, high=101.0, low=99.5), is_orb_period=True)
        orb.on_bar(_bar(101.0, high=102.5, low=100.0), is_orb_period=True)
        orb.on_bar(_bar(100.5, high=101.5, low=98.5), is_orb_period=True)
        assert orb._orb_high == 102.5
        assert orb._orb_low == 98.5

    def test_complete_range_sets_flag_and_avg_vol(self, orb_config):
        orb = ORBBreakout(orb_config)
        orb.on_bar(_bar(100, high=101, low=99, volume=1000), is_orb_period=True)
        orb.on_bar(_bar(101, high=102, low=100, volume=2000), is_orb_period=True)
        orb.complete_range()
        assert orb._orb_complete is True
        assert orb._avg_volume == pytest.approx(1500.0)

    def test_complete_range_no_bars_does_not_crash(self, orb_config):
        orb = ORBBreakout(orb_config)
        orb.complete_range()
        assert orb._orb_complete is False

    def test_get_range_reports_shape(self, orb_config):
        orb = ORBBreakout(orb_config)
        orb.on_bar(_bar(100, high=103, low=97), is_orb_period=True)
        orb.complete_range()
        r = orb.get_range()
        assert r["high"] == 103
        assert r["low"] == 97
        assert r["range"] == pytest.approx(6.0)
        assert r["complete"] is True


# ── Breakout logic ──

class TestBreakoutLogic:

    def _build_range(self, orb: ORBBreakout, high: float = 105.0, low: float = 100.0):
        """Helper: build a clean range and complete it."""
        orb.on_bar(_bar(101.0, high=high, low=low, volume=1000), is_orb_period=True)
        orb.complete_range()

    def test_no_signal_before_range_complete(self, orb_config):
        orb = ORBBreakout(orb_config)
        setup = orb.on_bar(_bar(110.0, volume=5000), is_orb_period=False)
        assert setup is None

    def test_long_breakout_fires(self, orb_config):
        orb = ORBBreakout(orb_config)
        self._build_range(orb)  # range 100-105
        # Close > 105 + 2 = 107 with volume > 1000 * 1.2 = 1200
        setup = orb.on_bar(_bar(108.0, volume=2000), is_orb_period=False)
        assert setup is not None
        assert setup.signal == Signal.LONG
        assert setup.entry_price == 108.0
        assert setup.stop_loss == 100.0  # orb low
        assert setup.take_profit == pytest.approx(108.0 + 5 * 1.5)

    def test_long_needs_buffer_above_high(self, orb_config):
        orb = ORBBreakout(orb_config)
        self._build_range(orb)  # range 100-105
        # close just barely above high (106 < 105 + 2) -> no trigger
        setup = orb.on_bar(_bar(106.0, volume=5000), is_orb_period=False)
        assert setup is None

    def test_short_breakout_fires(self, orb_config):
        orb = ORBBreakout(orb_config)
        self._build_range(orb)  # 100-105
        # close < 100 - 2 = 98 with volume ok
        setup = orb.on_bar(_bar(97.0, volume=2000), is_orb_period=False)
        assert setup is not None
        assert setup.signal == Signal.SHORT
        assert setup.stop_loss == 105.0
        assert setup.take_profit == pytest.approx(97.0 - 5 * 1.5)

    def test_volume_below_threshold_blocks(self, orb_config):
        orb = ORBBreakout(orb_config)
        self._build_range(orb)
        # volume 1100 < 1000 * 1.2 -> no signal
        setup = orb.on_bar(_bar(108.0, volume=1100), is_orb_period=False)
        assert setup is None

    def test_range_too_big_blocks(self, orb_config):
        orb = ORBBreakout(orb_config)
        # range = 20 > max_range_points=15
        self._build_range(orb, high=120.0, low=100.0)
        setup = orb.on_bar(_bar(125.0, volume=5000), is_orb_period=False)
        assert setup is None

    def test_range_too_small_blocks(self, orb_config):
        orb = ORBBreakout(orb_config)
        # range = 2 < min_range_points=3
        self._build_range(orb, high=102.0, low=100.0)
        setup = orb.on_bar(_bar(105.0, volume=5000), is_orb_period=False)
        assert setup is None

    def test_long_fires_only_once(self, orb_config):
        orb = ORBBreakout(orb_config)
        self._build_range(orb)
        first = orb.on_bar(_bar(108.0, volume=5000), is_orb_period=False)
        second = orb.on_bar(_bar(109.0, volume=5000), is_orb_period=False)
        assert first is not None
        assert second is None

    def test_max_trades_respected(self, orb_config):
        orb = ORBBreakout(orb_config)
        self._build_range(orb)
        # First trade: LONG
        first = orb.on_bar(_bar(108.0, volume=5000), is_orb_period=False)
        # Second: SHORT (different direction, allowed until max_trades)
        second = orb.on_bar(_bar(97.0, volume=5000), is_orb_period=False)
        # Max 2 trades - next breakout blocked
        orb._long_triggered = False
        orb._short_triggered = False
        third = orb.on_bar(_bar(110.0, volume=5000), is_orb_period=False)
        assert first is not None
        assert second is not None
        assert third is None

    def test_between_high_and_low_no_signal(self, orb_config):
        orb = ORBBreakout(orb_config)
        self._build_range(orb)
        setup = orb.on_bar(_bar(102.0, volume=5000), is_orb_period=False)
        assert setup is None


# ── reset_day ──

class TestResetDay:

    def test_reset_clears_all_state(self, orb_config):
        orb = ORBBreakout(orb_config)
        orb.on_bar(_bar(100, high=102, low=98), is_orb_period=True)
        orb.complete_range()
        orb._trades_taken = 2
        orb._long_triggered = True
        orb._short_triggered = True
        orb.reset_day()
        assert orb._orb_high is None
        assert orb._orb_low is None
        assert orb._orb_complete is False
        assert orb._trades_taken == 0
        assert orb._long_triggered is False
        assert orb._short_triggered is False
        assert orb._orb_bars == []
