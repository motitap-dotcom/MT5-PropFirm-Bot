"""Shared test fixtures for the TradeDay Futures Bot suite."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

# Make the `futures_bot` package importable when running `pytest` from repo root.
REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


@pytest.fixture
def guardian_config():
    """Baseline guardian configuration mirroring TradeDay $50K Intraday rules."""
    return {
        "initial_balance": 50000.0,
        "max_drawdown": 2000.0,
        "profit_target": 3000.0,
        "min_trading_days": 5,
        "consistency_pct": 0.30,
        "max_contracts": 5,
        "max_micro_contracts": 50,
        "dd_warning_pct": 0.60,
        "dd_critical_pct": 0.80,
        "dd_emergency_pct": 0.90,
        "max_daily_loss": 400.0,
        "max_daily_profit": 900.0,
        "max_daily_trades": 6,
    }


@pytest.fixture
def risk_config():
    return {
        "max_risk_per_trade": 150.0,
        "max_risk_pct": 0.003,
        "max_positions": 3,
        "max_contracts_per_trade": 5,
        "reduce_in_dead_zone": True,
    }


@pytest.fixture
def vwap_config():
    return {
        "rsi_period": 14,
        "rsi_oversold": 35,
        "rsi_overbought": 65,
        "max_consecutive_losses": 3,
        "min_atr": 0.0,   # disabled by default for tests
        "max_atr": 1e9,
        "atr_period": 14,
    }


@pytest.fixture
def orb_config():
    return {
        "buffer_ticks": 2.0,
        "tp_multiplier": 1.5,
        "max_range_points": 15.0,
        "min_range_points": 3.0,
        "volume_threshold": 1.2,
        "max_trades": 2,
    }


@pytest.fixture
def events_file(tmp_path):
    """Factory that writes a restricted_events.json and returns its path."""

    def _make(events):
        p = tmp_path / "restricted_events.json"
        p.write_text(json.dumps({"events": events}))
        return str(p)

    return _make
