"""
VWAP Mean Reversion Strategy
Primary strategy - high win rate (60-70%), small consistent profits.

Entry Logic:
  LONG: Price touches VWAP -1SD + RSI < 35 + bullish candle
  SHORT: Price touches VWAP +1SD + RSI > 65 + bearish candle

Exit Logic:
  TP1 (50%): VWAP line
  TP2 (50%): Opposite SD band
  SL: Beyond 2SD band
  Trailing: After TP1, move SL to breakeven
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
    take_profit_1: float  # 50% of position
    take_profit_2: float  # remaining 50%
    risk_dollars: float = 0.0


class VWAPMeanReversion:
    """VWAP Mean Reversion strategy for micro futures."""

    def __init__(self, config: dict):
        self.rsi_period: int = config.get("rsi_period", 14)
        self.rsi_oversold: float = config.get("rsi_oversold", 35)
        self.rsi_overbought: float = config.get("rsi_overbought", 65)
        self.max_consecutive_losses: int = config.get("max_consecutive_losses", 3)
        self.min_atr: float = config.get("min_atr", 2.0)  # MES points
        self.max_atr: float = config.get("max_atr", 8.0)
        self.atr_period: int = config.get("atr_period", 14)

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

        # Check if trend day (VWAP never crossed after 11:00 ET)
        # Disabled: still trade on trend days - strategy conditions are strict enough
        if self._trend_day_detected:
            logger.debug("Trend day detected, but continuing to scan for signals")

        # Calculate indicators
        vwap_data = self._calc_vwap()
        rsi = self._calc_rsi()
        atr = self._calc_atr()

        if atr < self.min_atr or atr > self.max_atr:
            return None  # Volatility filter

        current = self._bars[-1]
        prev = self._bars[-2]

        # Track VWAP crosses for trend day detection
        if (prev.close < vwap_data.vwap and current.close > vwap_data.vwap) or \
           (prev.close > vwap_data.vwap and current.close < vwap_data.vwap):
            self._vwap_crossed = True

        # LONG signal
        if (current.low <= vwap_data.lower_1sd and
                rsi < self.rsi_oversold and
                current.close > current.open):  # Bullish candle
            sl = vwap_data.lower_2sd - 2  # 2 points below -2SD
            tp1 = vwap_data.vwap
            tp2 = vwap_data.upper_1sd
            return TradeSetup(
                signal=Signal.LONG,
                entry_price=current.close,
                stop_loss=sl,
                take_profit_1=tp1,
                take_profit_2=tp2,
            )

        # SHORT signal
        if (current.high >= vwap_data.upper_1sd and
                rsi > self.rsi_overbought and
                current.close < current.open):  # Bearish candle
            sl = vwap_data.upper_2sd + 2
            tp1 = vwap_data.vwap
            tp2 = vwap_data.lower_1sd
            return TradeSetup(
                signal=Signal.SHORT,
                entry_price=current.close,
                stop_loss=sl,
                take_profit_1=tp1,
                take_profit_2=tp2,
            )

        return None

    def check_trend_day(self, current_hour_et: int):
        """Call after 11:00 ET to check if this is a trend day."""
        if current_hour_et >= 11 and not self._vwap_crossed:
            self._trend_day_detected = True
            logger.info("Trend day detected: VWAP not crossed by 11:00 ET")

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
