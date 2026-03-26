"""
Opening Range Breakout (ORB) Strategy
Secondary strategy - used on trend days when VWAP Mean Reversion fails.

Logic:
  1. Mark HIGH and LOW of first 30 minutes (9:30-10:00 ET)
  2. LONG: Price closes above HIGH + 2 ticks (with volume confirmation)
  3. SHORT: Price closes below LOW - 2 ticks (with volume confirmation)
  4. SL: Opposite side of the range
  5. TP: 1.5x the range size
  6. Max 2 trades per day from this strategy
"""

import logging
from dataclasses import dataclass
from typing import Optional, List
from enum import Enum

logger = logging.getLogger("strategy.orb")


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
class TradeSetup:
    signal: Signal
    entry_price: float
    stop_loss: float
    take_profit: float
    risk_dollars: float = 0.0


class ORBBreakout:
    """Opening Range Breakout strategy for micro futures."""

    def __init__(self, config: dict):
        self.buffer_ticks: float = config.get("buffer_ticks", 2.0)
        self.tp_multiplier: float = config.get("tp_multiplier", 1.5)
        self.max_range_points: float = config.get("max_range_points", 15.0)  # MES
        self.min_range_points: float = config.get("min_range_points", 3.0)
        self.volume_threshold: float = config.get("volume_threshold", 1.2)  # 120%
        self.max_trades: int = config.get("max_trades", 2)

        # State
        self._orb_bars: List[Bar] = []
        self._trading_bars: List[Bar] = []
        self._orb_high: Optional[float] = None
        self._orb_low: Optional[float] = None
        self._orb_complete: bool = False
        self._trades_taken: int = 0
        self._long_triggered: bool = False
        self._short_triggered: bool = False
        self._avg_volume: float = 0

    def reset_day(self):
        """Reset all state for a new trading day."""
        self._orb_bars = []
        self._trading_bars = []
        self._orb_high = None
        self._orb_low = None
        self._orb_complete = False
        self._trades_taken = 0
        self._long_triggered = False
        self._short_triggered = False
        self._avg_volume = 0

    def on_bar(self, bar: Bar, is_orb_period: bool) -> Optional[TradeSetup]:
        """
        Process a new bar.
        is_orb_period: True if between 9:30-10:00 ET
        """
        if is_orb_period:
            return self._build_range(bar)
        else:
            return self._check_breakout(bar)

    def _build_range(self, bar: Bar) -> None:
        """Accumulate bars during the opening range period."""
        self._orb_bars.append(bar)
        if self._orb_high is None or bar.high > self._orb_high:
            self._orb_high = bar.high
        if self._orb_low is None or bar.low < self._orb_low:
            self._orb_low = bar.low
        return None

    def complete_range(self):
        """Call at 10:00 ET to finalize the opening range."""
        if self._orb_high is not None and self._orb_low is not None:
            self._orb_complete = True
            range_size = self._orb_high - self._orb_low
            self._avg_volume = (
                sum(b.volume for b in self._orb_bars) / len(self._orb_bars)
                if self._orb_bars else 0
            )
            logger.info(
                f"ORB complete: HIGH={self._orb_high:.2f} LOW={self._orb_low:.2f} "
                f"Range={range_size:.2f} AvgVol={self._avg_volume:.0f}"
            )

    def _check_breakout(self, bar: Bar) -> Optional[TradeSetup]:
        """Check for breakout above/below the opening range."""
        if not self._orb_complete:
            return None

        if self._trades_taken >= self.max_trades:
            return None

        self._trading_bars.append(bar)

        range_size = self._orb_high - self._orb_low

        # Range too big or too small
        if range_size > self.max_range_points or range_size < self.min_range_points:
            return None

        # Volume confirmation
        volume_ok = bar.volume >= self._avg_volume * self.volume_threshold

        # LONG breakout
        if (not self._long_triggered and
                bar.close > self._orb_high + self.buffer_ticks and
                volume_ok):
            self._long_triggered = True
            self._trades_taken += 1

            sl = self._orb_low
            tp = bar.close + (range_size * self.tp_multiplier)

            logger.info(f"ORB LONG breakout: entry={bar.close:.2f} SL={sl:.2f} TP={tp:.2f}")
            return TradeSetup(
                signal=Signal.LONG,
                entry_price=bar.close,
                stop_loss=sl,
                take_profit=tp,
            )

        # SHORT breakout
        if (not self._short_triggered and
                bar.close < self._orb_low - self.buffer_ticks and
                volume_ok):
            self._short_triggered = True
            self._trades_taken += 1

            sl = self._orb_high
            tp = bar.close - (range_size * self.tp_multiplier)

            logger.info(f"ORB SHORT breakout: entry={bar.close:.2f} SL={sl:.2f} TP={tp:.2f}")
            return TradeSetup(
                signal=Signal.SHORT,
                entry_price=bar.close,
                stop_loss=sl,
                take_profit=tp,
            )

        return None

    def get_range(self) -> Optional[dict]:
        """Get current ORB range for dashboard."""
        if self._orb_high is None:
            return None
        return {
            "high": self._orb_high,
            "low": self._orb_low,
            "range": self._orb_high - self._orb_low,
            "complete": self._orb_complete,
        }
