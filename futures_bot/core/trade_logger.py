"""
Trade Logger — append each closed trade to a CSV for later review and learning.

Two files:
  - trades_log.csv: one row per closed trade (timestamp, symbol, pnl, r, etc.)
  - equity_curve.csv: one row per equity update (timestamp, balance, daily_pnl, dd_used)

Both files are created with headers on first use. Failures are logged but never raised —
trade logging must NEVER block the bot.
"""

import csv
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

logger = logging.getLogger("trade_logger")

TRADES_COLUMNS = [
    "timestamp_utc",
    "symbol",
    "strategy",
    "direction",
    "contracts",
    "entry",
    "sl",
    "tp",
    "exit",
    "pnl",
    "r_multiple",
    "reason",
    "daily_pnl_after",
    "balance_after",
]

EQUITY_COLUMNS = [
    "timestamp_utc",
    "balance",
    "daily_pnl",
    "total_pnl",
    "dd_used",
]


class TradeLogger:
    """Append-only CSV logger for trades and equity curve."""

    def __init__(self,
                 trades_path: str = "logs/trades_log.csv",
                 equity_path: str = "logs/equity_curve.csv"):
        self.trades_path = Path(trades_path)
        self.equity_path = Path(equity_path)
        self.trades_path.parent.mkdir(parents=True, exist_ok=True)
        self.equity_path.parent.mkdir(parents=True, exist_ok=True)
        self._ensure_header(self.trades_path, TRADES_COLUMNS)
        self._ensure_header(self.equity_path, EQUITY_COLUMNS)

    @staticmethod
    def _ensure_header(path: Path, columns: list):
        if path.exists() and path.stat().st_size > 0:
            return
        try:
            with open(path, "w", newline="") as f:
                csv.writer(f).writerow(columns)
        except Exception as e:
            logger.error(f"Failed to init {path}: {e}")

    def log_trade(self, trade: dict):
        """Append one closed trade. Missing keys default to empty string."""
        row = [trade.get(col, "") for col in TRADES_COLUMNS]
        if not row[0]:
            row[0] = datetime.now(timezone.utc).isoformat()
        try:
            with open(self.trades_path, "a", newline="") as f:
                csv.writer(f).writerow(row)
        except Exception as e:
            logger.error(f"Failed to log trade: {e}")

    def log_equity(self, balance: float, daily_pnl: float,
                   total_pnl: float, dd_used: float):
        """Append one equity point."""
        row = [
            datetime.now(timezone.utc).isoformat(),
            f"{balance:.2f}",
            f"{daily_pnl:.2f}",
            f"{total_pnl:.2f}",
            f"{dd_used:.2f}",
        ]
        try:
            with open(self.equity_path, "a", newline="") as f:
                csv.writer(f).writerow(row)
        except Exception as e:
            logger.error(f"Failed to log equity: {e}")
