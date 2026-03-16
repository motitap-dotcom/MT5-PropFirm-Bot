"""
Backtester - Simulates PropFirmBot strategies on historical data.
Implements the same SMC and EMA crossover logic as the MQL5 EA.
"""

import json
from dataclasses import dataclass, field
from datetime import datetime, time
from pathlib import Path

import numpy as np
import pandas as pd

try:
    from data_fetcher import (
        add_indicators,
        fetch_and_cache,
        load_from_csv,
        DEFAULT_SYMBOLS,
    )
except ImportError:
    # Allow importing Backtester without MetaTrader5 installed (for testing)
    add_indicators = None
    fetch_and_cache = None
    load_from_csv = None
    DEFAULT_SYMBOLS = ["EURUSD", "GBPUSD", "USDJPY", "XAUUSD"]

# --- Configuration ---
CONFIG_DIR = Path(__file__).parent.parent / "configs"
RESULTS_DIR = Path(__file__).parent.parent / "backtest_results"
RESULTS_DIR.mkdir(parents=True, exist_ok=True)


@dataclass
class TradeRecord:
    """Single trade record."""
    symbol: str
    direction: str        # "BUY" or "SELL"
    entry_time: datetime
    entry_price: float
    sl: float
    tp: float
    lot: float
    exit_time: datetime = None
    exit_price: float = 0.0
    pnl: float = 0.0
    pnl_pips: float = 0.0
    exit_reason: str = ""
    strategy: str = ""


@dataclass
class BacktestConfig:
    """Backtest parameters matching EA inputs."""
    account_size: float = 2000.0
    risk_per_trade: float = 0.75     # %
    max_risk_per_trade: float = 1.0  # %
    max_positions: int = 2
    daily_dd_guard: float = 3.0      # %
    total_dd_guard: float = 7.0      # %
    profit_target: float = 10.0      # %
    min_rr: float = 2.0
    max_spread_major: float = 3.0    # pips
    max_spread_xau: float = 5.0      # pips
    trailing_activation: float = 30  # pips
    trailing_distance: float = 20    # pips
    breakeven_activation: float = 20 # pips
    breakeven_offset: float = 2      # pips
    london_start: int = 7
    london_end: int = 11
    ny_start: int = 12
    ny_end: int = 16
    strategy: str = "SMC"            # "SMC" or "EMA" or "BOTH"
    challenge_mode: bool = True
    consistency_rule: bool = True
    consistency_max_day_pct: float = 40.0  # Max % of total profit from single day


class Backtester:
    """
    Backtesting engine for PropFirmBot strategies.
    Processes M15 bars sequentially, simulating the EA's logic.
    """

    def __init__(self, config: BacktestConfig = None):
        self.config = config or BacktestConfig()
        self.balance = self.config.account_size
        self.equity = self.config.account_size
        self.initial_balance = self.config.account_size
        self.daily_start_balance = self.config.account_size
        self.current_day = None

        self.trades: list[TradeRecord] = []
        self.open_positions: list[TradeRecord] = []
        self.equity_curve: list[dict] = []

        self.target_reached = False
        self.daily_dd_triggered = False
        self.total_dd_triggered = False
        self.trading_days = set()
        self.equity_high_water = self.config.account_size
        self.trailing_dd = self.config.daily_dd_guard <= 0  # Stellar Instant: no daily DD = trailing mode
        self.daily_pnl_tracker: dict[str, float] = {}  # date_str -> daily profit

    def reset(self):
        """Reset backtester state."""
        self.balance = self.config.account_size
        self.equity = self.config.account_size
        self.initial_balance = self.config.account_size
        self.daily_start_balance = self.config.account_size
        self.current_day = None
        self.trades = []
        self.open_positions = []
        self.equity_curve = []
        self.target_reached = False
        self.daily_dd_triggered = False
        self.total_dd_triggered = False
        self.trading_days = set()
        self.equity_high_water = self.config.account_size
        self.trailing_dd = self.config.daily_dd_guard <= 0
        self.daily_pnl_tracker = {}

    def _get_pip_size(self, symbol: str) -> float:
        if "JPY" in symbol:
            return 0.01
        if "XAU" in symbol or "GOLD" in symbol:
            return 0.01
        return 0.0001

    def _get_pip_value(self, symbol: str) -> float:
        """Approximate pip value per standard lot."""
        if "JPY" in symbol:
            return 6.7
        if "XAU" in symbol or "GOLD" in symbol:
            return 1.0
        return 10.0

    def _is_session_active(self, dt: datetime) -> bool:
        hour = dt.hour
        c = self.config
        return (c.london_start <= hour < c.london_end) or (c.ny_start <= hour < c.ny_end)

    def _is_weekend_close(self, dt: datetime) -> bool:
        return dt.weekday() == 4 and dt.hour >= 20  # Friday 20:00

    def _check_daily_reset(self, dt: datetime):
        day = dt.date()
        if self.current_day != day:
            self.current_day = day
            self.daily_start_balance = self.balance
            self.daily_dd_triggered = False

    def _is_daily_dd_ok(self) -> bool:
        if self.daily_start_balance <= 0:
            return False
        dd_pct = ((self.daily_start_balance - self.equity) / self.daily_start_balance) * 100
        return dd_pct < self.config.daily_dd_guard

    def _is_total_dd_ok(self) -> bool:
        if self.trailing_dd:
            # TRAILING DD: measured from equity high water mark (matches Guardian.mqh)
            if self.equity_high_water <= 0:
                return False
            dd_pct = ((self.equity_high_water - self.equity) / self.equity_high_water) * 100
        else:
            # FIXED DD: measured from initial balance
            if self.initial_balance <= 0:
                return False
            dd_pct = ((self.initial_balance - self.equity) / self.initial_balance) * 100
        return dd_pct < self.config.total_dd_guard

    def _calculate_lot(self, symbol: str, sl_distance_pips: float) -> float:
        if sl_distance_pips <= 0:
            return 0.0
        risk_amount = self.balance * (self.config.risk_per_trade / 100.0)
        pip_value = self._get_pip_value(symbol)
        lot = risk_amount / (sl_distance_pips * pip_value)
        lot = max(0.01, min(lot, 5.0))
        lot = round(lot, 2)
        return lot

    def _detect_ema_signal(self, row: pd.Series, prev_row: pd.Series, h4_bias: int) -> tuple:
        """
        EMA crossover signal detection.
        Returns (direction, sl_pips, tp_pips) or (None, 0, 0).
        """
        if pd.isna(row.get("ema_9")) or pd.isna(row.get("ema_21")):
            return None, 0, 0
        if pd.isna(prev_row.get("ema_9")) or pd.isna(prev_row.get("ema_21")):
            return None, 0, 0

        rsi = row.get("rsi_14", 50)
        atr = row.get("atr_14", 0)
        if atr <= 0:
            return None, 0, 0

        cross_up = (prev_row["ema_9"] <= prev_row["ema_21"]) and (row["ema_9"] > row["ema_21"])
        cross_down = (prev_row["ema_9"] >= prev_row["ema_21"]) and (row["ema_9"] < row["ema_21"])

        if cross_up and 30 < rsi < 70 and h4_bias >= 0:
            sl_distance = atr * 1.5
            tp_distance = sl_distance * self.config.min_rr
            return "BUY", sl_distance, tp_distance

        if cross_down and 30 < rsi < 70 and h4_bias <= 0:
            sl_distance = atr * 1.5
            tp_distance = sl_distance * self.config.min_rr
            return "SELL", sl_distance, tp_distance

        return None, 0, 0

    def _get_h4_bias(self, h4_df: pd.DataFrame, current_time: datetime) -> int:
        """Get H4 trend bias: +1 bullish, -1 bearish, 0 neutral."""
        if h4_df is None or h4_df.empty:
            return 0

        # Find the most recent H4 bar before current_time
        mask = h4_df["time"] <= current_time
        if mask.sum() < 2:
            return 0

        recent = h4_df[mask].iloc[-1]
        ema50 = recent.get("ema_50", None)
        ema200 = recent.get("ema_200", None)

        if ema50 is None or ema200 is None or pd.isna(ema50) or pd.isna(ema200):
            return 0

        close = recent["close"]
        if close > ema50 and ema50 > ema200:
            return 1
        if close < ema50 and ema50 < ema200:
            return -1
        return 0

    def _update_open_positions(self, row: pd.Series, symbol: str):
        """Check SL/TP/trailing/breakeven for open positions."""
        pip_size = self._get_pip_size(symbol)
        pip_value = self._get_pip_value(symbol)

        closed_indices = []

        for idx, trade in enumerate(self.open_positions):
            if trade.symbol != symbol:
                continue

            # Check Stop Loss
            if trade.direction == "BUY":
                if row["low"] <= trade.sl:
                    trade.exit_price = trade.sl
                    trade.exit_time = row["time"]
                    trade.exit_reason = "SL"
                    trade.pnl_pips = (trade.exit_price - trade.entry_price) / pip_size
                    trade.pnl = trade.pnl_pips * pip_value * trade.lot
                    closed_indices.append(idx)
                    continue

                # Check Take Profit
                if row["high"] >= trade.tp:
                    trade.exit_price = trade.tp
                    trade.exit_time = row["time"]
                    trade.exit_reason = "TP"
                    trade.pnl_pips = (trade.exit_price - trade.entry_price) / pip_size
                    trade.pnl = trade.pnl_pips * pip_value * trade.lot
                    closed_indices.append(idx)
                    continue

                # Breakeven
                profit_pips = (row["high"] - trade.entry_price) / pip_size
                if profit_pips >= self.config.breakeven_activation:
                    new_sl = trade.entry_price + self.config.breakeven_offset * pip_size
                    if new_sl > trade.sl:
                        trade.sl = new_sl

                # Trailing stop
                if profit_pips >= self.config.trailing_activation:
                    new_sl = row["close"] - self.config.trailing_distance * pip_size
                    if new_sl > trade.sl:
                        trade.sl = new_sl

            elif trade.direction == "SELL":
                if row["high"] >= trade.sl:
                    trade.exit_price = trade.sl
                    trade.exit_time = row["time"]
                    trade.exit_reason = "SL"
                    trade.pnl_pips = (trade.entry_price - trade.exit_price) / pip_size
                    trade.pnl = trade.pnl_pips * pip_value * trade.lot
                    closed_indices.append(idx)
                    continue

                if row["low"] <= trade.tp:
                    trade.exit_price = trade.tp
                    trade.exit_time = row["time"]
                    trade.exit_reason = "TP"
                    trade.pnl_pips = (trade.entry_price - trade.exit_price) / pip_size
                    trade.pnl = trade.pnl_pips * pip_value * trade.lot
                    closed_indices.append(idx)
                    continue

                profit_pips = (trade.entry_price - row["low"]) / pip_size
                if profit_pips >= self.config.breakeven_activation:
                    new_sl = trade.entry_price - self.config.breakeven_offset * pip_size
                    if new_sl < trade.sl:
                        trade.sl = new_sl

                if profit_pips >= self.config.trailing_activation:
                    new_sl = row["close"] + self.config.trailing_distance * pip_size
                    if new_sl < trade.sl:
                        trade.sl = new_sl

        # Move closed trades
        for idx in sorted(closed_indices, reverse=True):
            trade = self.open_positions.pop(idx)
            self.balance += trade.pnl
            self.trades.append(trade)
            # Track daily PnL for consistency rule
            if trade.exit_time is not None:
                day_key = str(trade.exit_time.date()) if hasattr(trade.exit_time, 'date') else str(trade.exit_time)
                self.daily_pnl_tracker[day_key] = self.daily_pnl_tracker.get(day_key, 0) + trade.pnl

    def _close_all_positions(self, row: pd.Series, reason: str):
        """Force close all open positions at current close price."""
        for trade in self.open_positions:
            pip_size = self._get_pip_size(trade.symbol)
            pip_value = self._get_pip_value(trade.symbol)

            trade.exit_price = row["close"]
            trade.exit_time = row["time"]
            trade.exit_reason = reason

            if trade.direction == "BUY":
                trade.pnl_pips = (trade.exit_price - trade.entry_price) / pip_size
            else:
                trade.pnl_pips = (trade.entry_price - trade.exit_price) / pip_size

            trade.pnl = trade.pnl_pips * pip_value * trade.lot
            self.balance += trade.pnl
            self.trades.append(trade)
            # Track daily PnL for consistency rule
            if trade.exit_time is not None:
                day_key = str(trade.exit_time.date()) if hasattr(trade.exit_time, 'date') else str(trade.exit_time)
                self.daily_pnl_tracker[day_key] = self.daily_pnl_tracker.get(day_key, 0) + trade.pnl

        self.open_positions = []

    def run(
        self,
        m15_data: dict[str, pd.DataFrame],
        h4_data: dict[str, pd.DataFrame] = None,
    ) -> pd.DataFrame:
        """
        Run backtest on provided data.

        Args:
            m15_data: dict of {symbol: DataFrame} with M15 OHLCV + indicators
            h4_data: dict of {symbol: DataFrame} with H4 data (optional)

        Returns:
            DataFrame of trade results
        """
        self.reset()

        # Merge all M15 data into a single timeline
        all_times = set()
        for symbol, df in m15_data.items():
            if not df.empty:
                all_times.update(df["time"].tolist())

        all_times = sorted(all_times)
        print(f"[Backtest] Processing {len(all_times)} M15 bars across {len(m15_data)} symbols")

        # Build lookup dicts for fast access
        data_lookup = {}
        for symbol, df in m15_data.items():
            df = df.set_index("time")
            data_lookup[symbol] = df

        # Prepare H4 data
        h4_prepared = {}
        if h4_data:
            for symbol, df in h4_data.items():
                if not df.empty:
                    df = df.copy()
                    df["ema_50"] = df["close"].ewm(span=50, adjust=False).mean()
                    df["ema_200"] = df["close"].ewm(span=200, adjust=False).mean()
                    h4_prepared[symbol] = df

        prev_rows = {}

        for t in all_times:
            # Daily reset
            self._check_daily_reset(t)

            # Update equity
            floating_pnl = 0
            for trade in self.open_positions:
                sym = trade.symbol
                if sym in data_lookup and t in data_lookup[sym].index:
                    price = data_lookup[sym].loc[t, "close"]
                    pip_size = self._get_pip_size(sym)
                    pip_value = self._get_pip_value(sym)
                    if trade.direction == "BUY":
                        floating_pnl += ((price - trade.entry_price) / pip_size) * pip_value * trade.lot
                    else:
                        floating_pnl += ((trade.entry_price - price) / pip_size) * pip_value * trade.lot

            self.equity = self.balance + floating_pnl
            if self.equity > self.equity_high_water:
                self.equity_high_water = self.equity

            # Record equity curve
            self.equity_curve.append({
                "time": t,
                "balance": self.balance,
                "equity": self.equity,
                "open_positions": len(self.open_positions),
            })

            # Process each symbol
            for symbol in m15_data.keys():
                if symbol not in data_lookup or t not in data_lookup[symbol].index:
                    continue

                row = data_lookup[symbol].loc[t]
                if isinstance(row, pd.DataFrame):
                    row = row.iloc[0]

                # Update open positions (SL/TP/trailing)
                row_dict = row.to_dict() if not isinstance(row, dict) else row
                row_series = pd.Series(row_dict)
                row_series["time"] = t
                self._update_open_positions(row_series, symbol)

                # Weekend close
                if self._is_weekend_close(t):
                    if self.open_positions:
                        self._close_all_positions(row_series, "Weekend")
                    continue

                # Drawdown guards
                if not self._is_daily_dd_ok():
                    if self.open_positions:
                        self._close_all_positions(row_series, "DailyDD")
                    continue
                if not self._is_total_dd_ok():
                    if self.open_positions:
                        self._close_all_positions(row_series, "TotalDD")
                    continue

                # Challenge mode check
                if self.config.challenge_mode and self.target_reached:
                    continue
                pnl_pct = ((self.equity - self.initial_balance) / self.initial_balance) * 100
                if self.config.challenge_mode and pnl_pct >= self.config.profit_target:
                    self.target_reached = True
                    continue

                # Session filter
                if not self._is_session_active(t):
                    continue

                # Max positions
                if len(self.open_positions) >= self.config.max_positions:
                    continue

                # Already have position on this symbol
                if any(p.symbol == symbol for p in self.open_positions):
                    continue

                # Get signal
                h4_bias = self._get_h4_bias(h4_prepared.get(symbol), t)
                prev = prev_rows.get(symbol)

                direction = None
                sl_distance = 0
                tp_distance = 0

                if prev is not None:
                    direction, sl_distance, tp_distance = self._detect_ema_signal(
                        row, prev, h4_bias
                    )

                prev_rows[symbol] = row

                if direction is None or sl_distance <= 0:
                    continue

                pip_size = self._get_pip_size(symbol)
                sl_pips = sl_distance / pip_size

                lot = self._calculate_lot(symbol, sl_pips)
                if lot <= 0:
                    continue

                # Create trade
                entry_price = row["close"]  # Simplified: enter at close of signal bar

                if direction == "BUY":
                    sl = entry_price - sl_distance
                    tp = entry_price + tp_distance
                else:
                    sl = entry_price + sl_distance
                    tp = entry_price - tp_distance

                trade = TradeRecord(
                    symbol=symbol,
                    direction=direction,
                    entry_time=t,
                    entry_price=entry_price,
                    sl=sl,
                    tp=tp,
                    lot=lot,
                    strategy=self.config.strategy,
                )
                self.open_positions.append(trade)
                self.trading_days.add(t.date() if hasattr(t, 'date') else t)

        # Close remaining positions at last bar
        if self.open_positions:
            for symbol in m15_data.keys():
                if symbol in data_lookup and len(data_lookup[symbol]) > 0:
                    last_row = data_lookup[symbol].iloc[-1]
                    last_row_series = pd.Series(last_row.to_dict())
                    last_row_series["time"] = all_times[-1]
                    self._close_all_positions(last_row_series, "EndOfTest")
                    break

        # Build results
        results_df = pd.DataFrame([vars(t) for t in self.trades])
        return results_df

    def get_equity_curve(self) -> pd.DataFrame:
        return pd.DataFrame(self.equity_curve)

    def get_summary(self) -> dict:
        """Calculate performance summary."""
        if not self.trades:
            return {"total_trades": 0}

        pnls = [t.pnl for t in self.trades]
        wins = [p for p in pnls if p > 0]
        losses = [p for p in pnls if p <= 0]

        gross_profit = sum(wins) if wins else 0
        gross_loss = abs(sum(losses)) if losses else 0

        # Max drawdown from equity curve
        eq_df = self.get_equity_curve()
        max_dd = 0
        max_dd_pct = 0
        if not eq_df.empty:
            peak = eq_df["equity"].cummax()
            dd = peak - eq_df["equity"]
            max_dd = dd.max()
            dd_pct = (dd / peak) * 100
            max_dd_pct = dd_pct.max()

        # Consistency rule check
        consistency_ok = True
        consistency_worst_day_pct = 0
        total_profit = sum(pnls)
        if self.config.consistency_rule and total_profit > 0 and self.daily_pnl_tracker:
            for day, day_pnl in self.daily_pnl_tracker.items():
                if day_pnl > 0:
                    day_pct = (day_pnl / total_profit) * 100
                    if day_pct > consistency_worst_day_pct:
                        consistency_worst_day_pct = day_pct
                    if day_pct > self.config.consistency_max_day_pct:
                        consistency_ok = False

        return {
            "total_trades": len(self.trades),
            "winning_trades": len(wins),
            "losing_trades": len(losses),
            "win_rate": len(wins) / len(self.trades) * 100 if self.trades else 0,
            "total_pnl": sum(pnls),
            "total_pnl_pct": (sum(pnls) / self.initial_balance) * 100,
            "gross_profit": gross_profit,
            "gross_loss": gross_loss,
            "profit_factor": gross_profit / gross_loss if gross_loss > 0 else float("inf"),
            "avg_win": np.mean(wins) if wins else 0,
            "avg_loss": np.mean(losses) if losses else 0,
            "max_drawdown": max_dd,
            "max_drawdown_pct": max_dd_pct,
            "final_balance": self.balance,
            "trading_days": len(self.trading_days),
            "target_reached": self.target_reached,
            "sharpe_ratio": (np.mean(pnls) / np.std(pnls) * np.sqrt(252)) if np.std(pnls) > 0 else 0,
            "consistency_ok": consistency_ok,
            "consistency_worst_day_pct": round(consistency_worst_day_pct, 1),
        }


def run_backtest(symbols=None, start_date=None, end_date=None, config=None):
    """Convenience function to run a full backtest."""
    if symbols is None:
        symbols = DEFAULT_SYMBOLS
    if config is None:
        config = BacktestConfig()

    print("=" * 60)
    print("PropFirmBot Backtester")
    print("=" * 60)

    # Load data
    m15_data = {}
    h4_data = {}
    for sym in symbols:
        df_m15 = load_from_csv(sym, "M15")
        if not df_m15.empty:
            m15_data[sym] = add_indicators(df_m15)

        df_h4 = load_from_csv(sym, "H4")
        if not df_h4.empty:
            h4_data[sym] = df_h4

    if not m15_data:
        print("[ERROR] No data available. Run data_fetcher.py first.")
        return None

    # Run
    bt = Backtester(config)
    results = bt.run(m15_data, h4_data)
    summary = bt.get_summary()

    # Print results
    print("\n" + "=" * 60)
    print("BACKTEST RESULTS")
    print("=" * 60)
    for key, val in summary.items():
        if isinstance(val, float):
            print(f"  {key:25s}: {val:.2f}")
        else:
            print(f"  {key:25s}: {val}")

    # Save results
    if not results.empty:
        results.to_csv(RESULTS_DIR / "backtest_trades.csv", index=False)
        print(f"\nTrades saved to {RESULTS_DIR / 'backtest_trades.csv'}")

    eq_curve = bt.get_equity_curve()
    if not eq_curve.empty:
        eq_curve.to_csv(RESULTS_DIR / "equity_curve.csv", index=False)

    return bt


if __name__ == "__main__":
    run_backtest()
