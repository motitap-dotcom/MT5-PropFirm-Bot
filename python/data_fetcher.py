"""
Data Fetcher - Download historical OHLCV data from MetaTrader 5.
Supports multiple symbols and timeframes with caching to CSV.
"""

import os
import sys
from datetime import datetime, timedelta
from pathlib import Path

import numpy as np
import pandas as pd

# MT5 is Windows-only; provide graceful fallback for backtesting on other OS
try:
    import MetaTrader5 as mt5
    MT5_AVAILABLE = True
except ImportError:
    MT5_AVAILABLE = False
    print("[DataFetcher] MetaTrader5 package not available - using CSV cache only")

# Project paths
DATA_DIR = Path(__file__).parent.parent / "backtest_results" / "data"
DATA_DIR.mkdir(parents=True, exist_ok=True)

# Timeframe mapping
TF_MAP = {
    "M1":  mt5.TIMEFRAME_M1  if MT5_AVAILABLE else 1,
    "M5":  mt5.TIMEFRAME_M5  if MT5_AVAILABLE else 5,
    "M15": mt5.TIMEFRAME_M15 if MT5_AVAILABLE else 15,
    "M30": mt5.TIMEFRAME_M30 if MT5_AVAILABLE else 30,
    "H1":  mt5.TIMEFRAME_H1  if MT5_AVAILABLE else 60,
    "H4":  mt5.TIMEFRAME_H4  if MT5_AVAILABLE else 240,
    "D1":  mt5.TIMEFRAME_D1  if MT5_AVAILABLE else 1440,
}

DEFAULT_SYMBOLS = ["EURUSD", "GBPUSD", "USDJPY", "XAUUSD"]
DEFAULT_TIMEFRAMES = ["M15", "H4"]


def init_mt5() -> bool:
    """Initialize MT5 connection."""
    if not MT5_AVAILABLE:
        print("[DataFetcher] MT5 not available on this platform")
        return False

    if not mt5.initialize():
        print(f"[DataFetcher] MT5 init failed: {mt5.last_error()}")
        return False

    info = mt5.terminal_info()
    if info:
        print(f"[DataFetcher] Connected to MT5: {info.name} | Build {info.build}")
    return True


def shutdown_mt5():
    """Shutdown MT5 connection."""
    if MT5_AVAILABLE:
        mt5.shutdown()


def fetch_ohlcv(
    symbol: str,
    timeframe: str = "M15",
    start_date: datetime = None,
    end_date: datetime = None,
    num_bars: int = None,
) -> pd.DataFrame:
    """
    Fetch OHLCV data from MT5.

    Args:
        symbol: Trading symbol (e.g. "EURUSD")
        timeframe: Timeframe string (e.g. "M15", "H4")
        start_date: Start date (default: 2 years ago)
        end_date: End date (default: now)
        num_bars: If set, fetch this many bars instead of date range

    Returns:
        DataFrame with columns: time, open, high, low, close, volume, spread
    """
    if not MT5_AVAILABLE:
        print(f"[DataFetcher] MT5 not available, trying CSV cache for {symbol}_{timeframe}")
        return load_from_csv(symbol, timeframe)

    tf_mt5 = TF_MAP.get(timeframe)
    if tf_mt5 is None:
        print(f"[DataFetcher] Unknown timeframe: {timeframe}")
        return pd.DataFrame()

    if end_date is None:
        end_date = datetime.now()
    if start_date is None and num_bars is None:
        start_date = end_date - timedelta(days=730)  # 2 years

    if num_bars:
        rates = mt5.copy_rates_from(symbol, tf_mt5, end_date, num_bars)
    else:
        rates = mt5.copy_rates_range(symbol, tf_mt5, start_date, end_date)

    if rates is None or len(rates) == 0:
        print(f"[DataFetcher] No data for {symbol} {timeframe}: {mt5.last_error()}")
        return pd.DataFrame()

    df = pd.DataFrame(rates)
    df["time"] = pd.to_datetime(df["time"], unit="s")
    df.rename(columns={"tick_volume": "volume"}, inplace=True)

    # Keep relevant columns
    cols = ["time", "open", "high", "low", "close", "volume"]
    if "spread" in df.columns:
        cols.append("spread")
    df = df[cols]

    print(f"[DataFetcher] {symbol} {timeframe}: {len(df)} bars "
          f"({df['time'].iloc[0]} to {df['time'].iloc[-1]})")

    return df


def save_to_csv(df: pd.DataFrame, symbol: str, timeframe: str):
    """Save DataFrame to CSV cache."""
    if df.empty:
        return
    filepath = DATA_DIR / f"{symbol}_{timeframe}.csv"
    df.to_csv(filepath, index=False)
    print(f"[DataFetcher] Saved {len(df)} bars to {filepath}")


def load_from_csv(symbol: str, timeframe: str) -> pd.DataFrame:
    """Load DataFrame from CSV cache."""
    filepath = DATA_DIR / f"{symbol}_{timeframe}.csv"
    if not filepath.exists():
        print(f"[DataFetcher] Cache not found: {filepath}")
        return pd.DataFrame()

    df = pd.read_csv(filepath, parse_dates=["time"])
    print(f"[DataFetcher] Loaded {len(df)} bars from {filepath}")
    return df


def fetch_and_cache(
    symbols: list = None,
    timeframes: list = None,
    start_date: datetime = None,
    end_date: datetime = None,
) -> dict:
    """
    Fetch data for multiple symbols/timeframes and cache to CSV.

    Returns:
        dict of {(symbol, timeframe): DataFrame}
    """
    if symbols is None:
        symbols = DEFAULT_SYMBOLS
    if timeframes is None:
        timeframes = DEFAULT_TIMEFRAMES

    results = {}

    connected = init_mt5()

    for symbol in symbols:
        for tf in timeframes:
            if connected:
                df = fetch_ohlcv(symbol, tf, start_date, end_date)
                if not df.empty:
                    save_to_csv(df, symbol, tf)
            else:
                df = load_from_csv(symbol, tf)

            results[(symbol, tf)] = df

    if connected:
        shutdown_mt5()

    return results


def add_indicators(df: pd.DataFrame) -> pd.DataFrame:
    """
    Add technical indicators used by the EA to the DataFrame.
    Useful for backtesting without MT5 indicator handles.
    """
    if df.empty:
        return df

    df = df.copy()

    # EMA 9 and EMA 21
    df["ema_9"] = df["close"].ewm(span=9, adjust=False).mean()
    df["ema_21"] = df["close"].ewm(span=21, adjust=False).mean()

    # RSI 14
    delta = df["close"].diff()
    gain = delta.where(delta > 0, 0.0)
    loss = (-delta).where(delta < 0, 0.0)
    avg_gain = gain.ewm(com=13, adjust=False).mean()
    avg_loss = loss.ewm(com=13, adjust=False).mean()
    rs = avg_gain / avg_loss.replace(0, np.nan)
    df["rsi_14"] = 100 - (100 / (1 + rs))

    # ATR 14
    high_low = df["high"] - df["low"]
    high_close = (df["high"] - df["close"].shift()).abs()
    low_close = (df["low"] - df["close"].shift()).abs()
    true_range = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
    df["atr_14"] = true_range.ewm(span=14, adjust=False).mean()

    # EMA crossover signal
    df["ema_cross_up"] = (df["ema_9"] > df["ema_21"]) & (df["ema_9"].shift() <= df["ema_21"].shift())
    df["ema_cross_down"] = (df["ema_9"] < df["ema_21"]) & (df["ema_9"].shift() >= df["ema_21"].shift())

    return df


# --- CLI usage ---
if __name__ == "__main__":
    print("=" * 50)
    print("PropFirmBot Data Fetcher")
    print("=" * 50)

    symbols = sys.argv[1:] if len(sys.argv) > 1 else DEFAULT_SYMBOLS
    data = fetch_and_cache(symbols=symbols)

    for (sym, tf), df in data.items():
        if not df.empty:
            print(f"\n{sym} {tf}: {len(df)} bars | "
                  f"Range: {df['time'].iloc[0]} to {df['time'].iloc[-1]}")
