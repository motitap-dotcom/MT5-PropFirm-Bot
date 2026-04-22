"""Tests for futures_bot.strategies.vwap_mean_reversion."""

from __future__ import annotations

import math

import pytest

from futures_bot.strategies.vwap_mean_reversion import (
    Bar,
    Signal,
    VWAPMeanReversion,
)


def _bar(close: float, *, volume: float = 100.0, high: float = None,
         low: float = None, open_: float = None, timestamp: str = "t") -> Bar:
    """Convenience: build a Bar where OHLC all equal `close` unless overridden."""
    return Bar(
        timestamp=timestamp,
        open=open_ if open_ is not None else close,
        high=high if high is not None else close,
        low=low if low is not None else close,
        close=close,
        volume=volume,
    )


# ── VWAP math ──

class TestVWAPMath:

    def test_empty_history_returns_zero_vwap(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        data = s.get_vwap_data()
        assert data.vwap == 0.0

    def test_single_bar_vwap_equals_typical_price(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        s._update_vwap(_bar(100.0, high=102, low=98))
        data = s._calc_vwap()
        # typical = (102 + 98 + 100) / 3 = 100
        assert data.vwap == pytest.approx(100.0)
        # SD with one sample = 0
        assert data.upper_1sd == pytest.approx(100.0)
        assert data.lower_1sd == pytest.approx(100.0)

    def test_vwap_weighted_by_volume(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        # Two bars: typical=100 @ vol=100, typical=110 @ vol=300
        # Weighted = (100*100 + 110*300) / 400 = (10000 + 33000)/400 = 107.5
        s._update_vwap(_bar(100.0, high=100, low=100, volume=100))
        s._update_vwap(_bar(110.0, high=110, low=110, volume=300))
        assert s._calc_vwap().vwap == pytest.approx(107.5)

    def test_vwap_bands_symmetric(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        for px in (95, 100, 105):
            s._update_vwap(_bar(px, high=px, low=px, volume=100))
        data = s._calc_vwap()
        # upper/lower 1SD symmetric around vwap
        assert data.upper_1sd - data.vwap == pytest.approx(data.vwap - data.lower_1sd)
        assert data.upper_2sd - data.vwap == pytest.approx(data.vwap - data.lower_2sd)
        assert data.upper_2sd - data.vwap == pytest.approx(2 * (data.upper_1sd - data.vwap))

    def test_variance_never_negative(self, vwap_config):
        """Floating-point can produce tiny negative variance; code must guard."""
        s = VWAPMeanReversion(vwap_config)
        # Identical bars -> variance should be exactly 0 (or near it)
        for _ in range(5):
            s._update_vwap(_bar(100.0, high=100, low=100, volume=100))
        data = s._calc_vwap()
        assert not math.isnan(data.upper_1sd)
        assert data.upper_1sd >= data.vwap  # never NaN, never crossed


# ── RSI math ──

class TestRSIMath:

    def test_not_enough_bars_returns_neutral(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        # fewer than rsi_period+1 bars -> neutral 50
        for _ in range(3):
            s._bars.append(_bar(100.0))
        assert s._calc_rsi(period=14) == 50.0

    def test_all_gains_returns_100(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        for i in range(20):
            s._bars.append(_bar(100.0 + i))
        assert s._calc_rsi(period=14) == 100.0

    def test_all_losses_returns_zero(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        for i in range(20):
            s._bars.append(_bar(100.0 - i))
        rsi = s._calc_rsi(period=14)
        assert rsi == pytest.approx(0.0)

    def test_balanced_moves_near_50(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        # Alternating +1/-1 moves produce equal avg gain/loss -> RSI=50
        price = 100.0
        s._bars.append(_bar(price))
        for i in range(20):
            price += 1 if i % 2 == 0 else -1
            s._bars.append(_bar(price))
        rsi = s._calc_rsi(period=14)
        assert rsi == pytest.approx(50.0, abs=1e-6)


# ── ATR math ──

class TestATRMath:

    def test_not_enough_bars_returns_zero(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        for _ in range(3):
            s._bars.append(_bar(100.0))
        assert s._calc_atr() == 0.0

    def test_constant_bars_have_zero_atr(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        for _ in range(20):
            s._bars.append(_bar(100.0, high=100.0, low=100.0))
        assert s._calc_atr() == pytest.approx(0.0)

    def test_atr_equals_bar_range_when_no_gaps(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        # Every bar has H-L=2 and no gaps
        for _ in range(20):
            s._bars.append(_bar(100.0, high=101.0, low=99.0))
        assert s._calc_atr() == pytest.approx(2.0)

    def test_atr_accounts_for_gaps(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        # First bar: close=100
        s._bars.append(_bar(100.0, high=100.0, low=100.0))
        # Next 14 bars: each has H-L=1 but gaps +5 from prev close (TR=5)
        prev_close = 100.0
        for _ in range(14):
            new_close = prev_close + 5
            s._bars.append(
                Bar(timestamp="t", open=new_close, high=new_close + 0.5,
                    low=new_close - 0.5, close=new_close, volume=100)
            )
            prev_close = new_close
        atr = s._calc_atr()
        # TR each = max(1, |H - prev_close|=5.5, |L - prev_close|=4.5) = 5.5
        assert atr == pytest.approx(5.5)


# ── on_bar: signal generation ──

class TestSignalGeneration:

    def _warm_up(self, s: VWAPMeanReversion, n: int = 20, price: float = 100.0):
        """Feed identical bars to prime VWAP + RSI without creating a signal."""
        for _ in range(n):
            s.on_bar(_bar(price, high=price, low=price))

    def test_no_signal_before_enough_bars(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        for _ in range(5):  # fewer than rsi_period+5
            setup = s.on_bar(_bar(100.0))
            assert setup is None

    def test_paused_on_max_consecutive_losses(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        self._warm_up(s, n=25)
        s._consecutive_losses = s.max_consecutive_losses
        assert s.on_bar(_bar(100.0)) is None

    def test_trend_day_pauses_signals(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        self._warm_up(s, n=25)
        s._trend_day_detected = True
        assert s.on_bar(_bar(100.0)) is None

    def test_long_signal_fired_on_oversold_touch(self, vwap_config):
        """Declining market -> RSI oversold; bar touches -1SD with bullish close."""
        s = VWAPMeanReversion(vwap_config)
        # Build a downtrend long enough to pull RSI < 35 and establish VWAP/SD bands
        price = 110.0
        for _ in range(25):
            s.on_bar(_bar(price, high=price + 0.2, low=price - 0.2))
            price -= 0.3

        vwap_data = s._calc_vwap()
        # Drop current bar to below lower_1sd with bullish candle (close > open)
        trigger_low = vwap_data.lower_1sd - 0.1
        trigger = Bar(
            timestamp="t",
            open=trigger_low,
            high=trigger_low + 0.1,
            low=trigger_low - 0.05,
            close=trigger_low + 0.1,  # bullish
            volume=100,
        )
        rsi = s._calc_rsi()
        assert rsi < s.rsi_oversold  # sanity
        setup = s.on_bar(trigger)
        assert setup is not None
        assert setup.signal == Signal.LONG
        assert setup.stop_loss < setup.entry_price
        assert setup.take_profit_1 > setup.entry_price
        assert setup.take_profit_2 > setup.take_profit_1

    def test_short_signal_fired_on_overbought_touch(self, vwap_config):
        """Rising market -> RSI overbought; bar touches +1SD with bearish close."""
        s = VWAPMeanReversion(vwap_config)
        price = 90.0
        for _ in range(25):
            s.on_bar(_bar(price, high=price + 0.2, low=price - 0.2))
            price += 0.3

        vwap_data = s._calc_vwap()
        trigger_high = vwap_data.upper_1sd + 0.1
        trigger = Bar(
            timestamp="t",
            open=trigger_high,
            high=trigger_high + 0.05,
            low=trigger_high - 0.1,
            close=trigger_high - 0.1,  # bearish
            volume=100,
        )
        rsi = s._calc_rsi()
        assert rsi > s.rsi_overbought
        setup = s.on_bar(trigger)
        assert setup is not None
        assert setup.signal == Signal.SHORT
        assert setup.stop_loss > setup.entry_price
        assert setup.take_profit_1 < setup.entry_price
        assert setup.take_profit_2 < setup.take_profit_1


# ── Trend day detection ──

class TestTrendDay:

    def test_trend_day_not_flagged_before_11(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        s.check_trend_day(current_hour_et=10)
        assert s.is_trend_day() is False

    def test_trend_day_flagged_when_no_cross_by_11(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        s.check_trend_day(current_hour_et=11)
        assert s.is_trend_day() is True

    def test_trend_day_not_flagged_if_vwap_crossed(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        s._vwap_crossed = True
        s.check_trend_day(current_hour_et=11)
        assert s.is_trend_day() is False


# ── record_trade_result ──

class TestTradeResultTracking:

    def test_wins_reset_loss_streak(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        s._consecutive_losses = 2
        s.record_trade_result(is_win=True)
        assert s._consecutive_losses == 0

    def test_losses_increment_streak(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        s.record_trade_result(is_win=False)
        s.record_trade_result(is_win=False)
        assert s._consecutive_losses == 2


# ── reset_day ──

class TestResetDay:

    def test_reset_clears_all_state(self, vwap_config):
        s = VWAPMeanReversion(vwap_config)
        s._bars.append(_bar(100.0))
        s._cum_volume = 500
        s._cum_vp = 50000
        s._cum_vp2 = 5000000
        s._consecutive_losses = 2
        s._trend_day_detected = True
        s._vwap_crossed = True
        s.reset_day()
        assert s._bars == []
        assert s._cum_volume == 0
        assert s._cum_vp == 0
        assert s._cum_vp2 == 0
        assert s._consecutive_losses == 0
        assert s._trend_day_detected is False
        assert s._vwap_crossed is False
