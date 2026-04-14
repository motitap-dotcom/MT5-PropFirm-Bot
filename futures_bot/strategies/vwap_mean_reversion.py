"""
VWAP Mean Reversion Strategy
Primary strategy - high win rate (60-70%), small consistent profits.

Entry Logic:
  LONG: Price touches VWAP -1SD + RSI < oversold + bullish candle + volume filter
  SHORT: Price touches VWAP +1SD + RSI > overbought + bearish candle + volume filter

Exit Logic:
  TP1 (default 60%): VWAP line
  TP2 (default 40%): VWAP ± tp2_sd_multiplier × SD
  SL: Beyond 2SD band by sl_atr_multiplier × ATR
  Trailing: After TP1, trail stop at (entry ± trailing_atr_after_tp1 × ATR)
"""

import logging
from dataclasses import dataclass, field
from typing import Optional, List
from enum import Enum
import math

logger = logging.getLogger("strategy.vwap")


class Signal(Enum):
    NONE = 0
    LONG = 1
    SHORT = 2


@dataclass
class Bar:
    timestamp: str
    open: float
    high: float
    low: float
    close: float
    volume: float


@dataclass
class VWAPData:
    vwap: float = 0.0
    upper_1sd: float = 0.0
    lower_1sd: float = 0.0
    upper_2sd: float = 0.0
    lower_2sd: float = 0.0


@dataclass
class TradeSetup:
    signal: Signal
    entry_price: float
    stop_loss: float
    take_profit_1: float  # first partial exit (tp1_size_pct of position)
    take_profit_2: float  # remaining exit (tp2_size_pct of position)
    tp1_size_pct: float = 0.6
    tp2_size_pct: float = 0.4
    trailing_atr: float = 0.0  # ATR value to use for post-TP1 trailing
    risk_dollars: float = 0.0


class VWAPMeanReversion:
    """VWAP Mean Reversion strategy for micro futures."""

    def __init__(self, config: dict):
        self.rsi_period: int = config.get("rsi_period", 14)
        self.rsi_oversold: float = config.get("rsi_oversold", 30)
        self.rsi_overbought: float = config.get("rsi_overbought", 70)
        self.max_consecutive_losses: int = config.get("max_consecutive_losses", 3)
        self.min_atr: float = config.get("min_atr", 0.5)
        self.max_atr: float = config.get("max_atr", 500.0)
        self.atr_period: int = config.get("atr_period", 14)

        # Risk/reward tuning (previously hardcoded)
        self.sl_atr_multiplier: float = config.get("sl_atr_multiplier", 0.5)
        self.tp2_sd_multiplier: float = config.get("tp2_sd_multiplier", 1.5)
        self.tp1_size_pct: float = config.get("tp1_size_pct", 0.6)
        self.tp2_size_pct: float = config.get("tp2_size_pct", 0.4)
        self.trailing_atr_after_tp1: float = config.get("trailing_atr_after_tp1", 1.0)
        self.min_volume_ratio: float = config.get("min_volume_ratio", 1.0)
        self.trend_day_check_hour: int = config.get("trend_day_check_hour", 11)

        # State
        self._bars: List[Bar] = []
        self._cum_volume: float = 0
        self._cum_vp: float = 0  # volume * price
        self._cum_vp2: float = 0  # volume * price^2
        self._consecutive_losses: int = 0
        self._trend_day_detected: bool = False
        self._vwap_crossed: bool = False
        self._day_started: bool = False

    def reset_day(self):
        """Reset all state for a new trading day."""
        self._bars = []
        self._cum_volume = 0
        self._cum_vp = 0
        self._cum_vp2 = 0
        self._consecutive_losses = 0
        self._trend_day_detected = False
        self._vwap_crossed = False
        self._day_started = True

    def on_bar(self, bar: Bar) -> Optional[TradeSetup]:
        """Process a new bar and return a trade setup if conditions met."""
        self._bars.append(bar)
        self._update_vwap(bar)

        # Need enough bars for indicators
        if len(self._bars) < self.rsi_period + 5:
            return None

        # Check if too many consecutive losses
        if self._consecutive_losses >= self.max_consecutive_losses:
            logger.info(f"Max consecutive losses ({self.max_consecutive_losses}) reached, pausing")
            return None

        # Calculate indicators
        vwap_data = self._calc_vwap()
        rsi = self._calc_rsi()
        atr = self._calc_atr()

        current = self._bars[-1]
        prev = self._bars[-2]

        # Calculate distance from VWAP in SD units
        sd = vwap_data.upper_1sd - vwap_data.vwap  # 1 SD value
        if sd == 0:
            return None
        dist_sd = (current.close - vwap_data.vwap) / sd  # Positive = above VWAP

        logger.info(f"Price={current.close:.2f} VWAP={vwap_data.vwap:.2f} "
                     f"dist={dist_sd:+.2f}SD RSI={rsi:.1f} ATR={atr:.2f}")

        # Track VWAP crosses
        if (prev.close < vwap_data.vwap and current.close > vwap_data.vwap) or \
           (prev.close > vwap_data.vwap and current.close < vwap_data.vwap):
            self._vwap_crossed = True

        # ATR volatility filter
        if atr < self.min_atr or atr > self.max_atr:
            return None

        # Volume filter: require current bar volume >= rolling avg * min_volume_ratio
        avg_vol = self._recent_avg_volume()
        if avg_vol > 0 and current.volume < avg_vol * self.min_volume_ratio:
            return None

        # LONG signal: price touches lower 1SD + RSI oversold + bullish candle
        if (current.low <= vwap_data.lower_1sd and
                rsi < self.rsi_oversold and
                current.close > current.open):
            sl = vwap_data.lower_2sd - (atr * self.sl_atr_multiplier)
            tp1 = vwap_data.vwap
            tp2 = vwap_data.vwap + (sd * self.tp2_sd_multiplier)
            logger.info(f">>> LONG SIGNAL: dist={dist_sd:.2f}SD RSI={rsi:.1f} "
                        f"entry={current.close:.2f} sl={sl:.2f} tp1={tp1:.2f} tp2={tp2:.2f}")
            return TradeSetup(
                signal=Signal.LONG,
                entry_price=current.close,
                stop_loss=sl,
                take_profit_1=tp1,
                take_profit_2=tp2,
                tp1_size_pct=self.tp1_size_pct,
                tp2_size_pct=self.tp2_size_pct,
                trailing_atr=atr * self.trailing_atr_after_tp1,
            )

        # SHORT signal: price touches upper 1SD + RSI overbought + bearish candle
        if (current.high >= vwap_data.upper_1sd and
                rsi > self.rsi_overbought and
                current.close < current.open):
            sl = vwap_data.upper_2sd + (atr * self.sl_atr_multiplier)
            tp1 = vwap_data.vwap
            tp2 = vwap_data.vwap - (sd * self.tp2_sd_multiplier)
            logger.info(f">>> SHORT SIGNAL: dist={dist_sd:.2f}SD RSI={rsi:.1f} "
                        f"entry={current.close:.2f} sl={sl:.2f} tp1={tp1:.2f} tp2={tp2:.2f}")
            return TradeSetup(
                signal=Signal.SHORT,
                entry_price=current.close,
                stop_loss=sl,
                take_profit_1=tp1,
                take_profit_2=tp2,
                tp1_size_pct=self.tp1_size_pct,
                tp2_size_pct=self.tp2_size_pct,
                trailing_atr=atr * self.trailing_atr_after_tp1,
            )

        return None

    def _recent_avg_volume(self, lookback: int = 20) -> float:
        """Rolling average volume of last `lookback` bars (excluding current)."""
        if len(self._bars) < 2:
            return 0.0
        window = self._bars[-(lookback + 1):-1]
        if not window:
            return 0.0
        return sum(b.volume for b in window) / len(window)

    def check_trend_day(self, current_hour_et: int):
        """Call after the configured check hour to detect a trend day."""
        if current_hour_et >= self.trend_day_check_hour and not self._vwap_crossed:
            self._trend_day_detected = True
            logger.info(
                f"Trend day detected: VWAP not crossed by {self.trend_day_check_hour:02d}:00 ET"
            )

    def is_trend_day(self) -> bool:
        return self._trend_day_detected

    def record_trade_result(self, is_win: bool):
        """Track consecutive losses."""
        if is_win:
            self._consecutive_losses = 0
        else:
            self._consecutive_losses += 1

    # ── Indicator Calculations ──

    def _update_vwap(self, bar: Bar):
        """Update running VWAP components."""
        typical_price = (bar.high + bar.low + bar.close) / 3
        self._cum_volume += bar.volume
        self._cum_vp += bar.volume * typical_price
        self._cum_vp2 += bar.volume * typical_price * typical_price

    def _calc_vwap(self) -> VWAPData:
        """Calculate VWAP and standard deviation bands."""
        if self._cum_volume == 0:
            return VWAPData()

        vwap = self._cum_vp / self._cum_volume
        variance = (self._cum_vp2 / self._cum_volume) - (vwap * vwap)
        sd = math.sqrt(max(variance, 0))

        return VWAPData(
            vwap=vwap,
            upper_1sd=vwap + sd,
            lower_1sd=vwap - sd,
            upper_2sd=vwap + 2 * sd,
            lower_2sd=vwap - 2 * sd,
        )

    def _calc_rsi(self, period: int = None) -> float:
        """Calculate RSI from recent bars."""
        period = period or self.rsi_period
        if len(self._bars) < period + 1:
            return 50.0  # Neutral

        gains = 0.0
        losses = 0.0
        for i in range(-period, 0):
            change = self._bars[i].close - self._bars[i - 1].close
            if change > 0:
                gains += change
            else:
                losses += abs(change)

        avg_gain = gains / period
        avg_loss = losses / period

        if avg_loss == 0:
            return 100.0
        rs = avg_gain / avg_loss
        return 100 - (100 / (1 + rs))

    def _calc_atr(self) -> float:
        """Calculate Average True Range."""
        if len(self._bars) < self.atr_period + 1:
            return 0.0

        true_ranges = []
        for i in range(-self.atr_period, 0):
            bar = self._bars[i]
            prev = self._bars[i - 1]
            tr = max(
                bar.high - bar.low,
                abs(bar.high - prev.close),
                abs(bar.low - prev.close),
            )
            true_ranges.append(tr)

        return sum(true_ranges) / len(true_ranges)

    def get_vwap_data(self) -> VWAPData:
        """Get current VWAP data for dashboard/logging."""
        return self._calc_vwap()
