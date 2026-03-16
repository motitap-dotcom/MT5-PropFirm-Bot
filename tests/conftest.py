"""Shared test fixtures for PropFirmBot tests."""

import sys
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

# Add python/ to path so we can import backtester without data_fetcher dependency
sys.path.insert(0, str(Path(__file__).parent.parent / "python"))

CONFIGS_DIR = Path(__file__).parent.parent / "configs"


@pytest.fixture
def configs_dir():
    return CONFIGS_DIR


@pytest.fixture
def synthetic_m15_uptrend():
    """Generate M15 OHLCV data with clear uptrend and EMA crossover."""
    np.random.seed(42)
    dates = pd.date_range("2025-01-06 08:00", periods=200, freq="15min")
    prices = np.linspace(1.1000, 1.1200, 200) + np.random.normal(0, 0.0002, 200)
    df = pd.DataFrame({
        "time": dates,
        "open": prices - 0.0002,
        "high": prices + 0.0005,
        "low": prices - 0.0005,
        "close": prices,
        "volume": np.random.randint(100, 1000, 200),
    })
    # Add indicators
    df["ema_9"] = df["close"].ewm(span=9, adjust=False).mean()
    df["ema_21"] = df["close"].ewm(span=21, adjust=False).mean()
    df["rsi_14"] = 50.0  # Neutral RSI
    df["atr_14"] = 0.0010  # 10 pips ATR
    return df


@pytest.fixture
def synthetic_m15_downtrend():
    """Generate M15 OHLCV data with clear downtrend."""
    np.random.seed(43)
    dates = pd.date_range("2025-01-06 08:00", periods=200, freq="15min")
    prices = np.linspace(1.1200, 1.1000, 200) + np.random.normal(0, 0.0002, 200)
    df = pd.DataFrame({
        "time": dates,
        "open": prices + 0.0002,
        "high": prices + 0.0005,
        "low": prices - 0.0005,
        "close": prices,
        "volume": np.random.randint(100, 1000, 200),
    })
    df["ema_9"] = df["close"].ewm(span=9, adjust=False).mean()
    df["ema_21"] = df["close"].ewm(span=21, adjust=False).mean()
    df["rsi_14"] = 50.0
    df["atr_14"] = 0.0010
    return df
