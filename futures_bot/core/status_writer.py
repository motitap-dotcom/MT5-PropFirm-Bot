"""
Status Writer - Writes bot status to JSON file for monitoring.

Two outputs:
  - status/status.json         — full machine-readable snapshot
  - status/dashboard.txt       — human-readable one-pager for quick eyeballing
"""

import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Any, Optional

logger = logging.getLogger("status_writer")


class StatusWriter:
    """Writes periodic status snapshots for external monitoring."""

    def __init__(self,
                 output_path: str = "status/status.json",
                 dashboard_path: str = "status/dashboard.txt"):
        self.output_path = Path(output_path)
        self.dashboard_path = Path(dashboard_path)
        self.output_path.parent.mkdir(parents=True, exist_ok=True)
        self.dashboard_path.parent.mkdir(parents=True, exist_ok=True)

    def write(self, guardian_status: Dict, risk_status: Dict = None,
              positions: list = None, extra: Dict = None):
        """Write a complete status snapshot."""
        status = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "bot": "TradeDay Futures Bot",
            "platform": "Tradovate",
            "guardian": guardian_status,
            "positions": positions or [],
            "risk": risk_status or {},
        }
        if extra:
            status.update(extra)

        try:
            self.output_path.parent.mkdir(parents=True, exist_ok=True)
            with open(self.output_path, "w") as f:
                json.dump(status, f, indent=2)
        except Exception as e:
            logger.error(f"Failed to write status: {e}")

        # Also render human-readable dashboard (best-effort)
        try:
            self.write_dashboard(status)
        except Exception as e:
            logger.error(f"Failed to render dashboard: {e}")

    def write_dashboard(self, status: Dict[str, Any]):
        """Render a single-page human-readable status snapshot."""
        g = status.get("guardian", {}) or {}
        positions = status.get("positions") or []
        active = status.get("active_strategy") or {}
        ts = status.get("timestamp", "")

        balance = g.get("balance", 0.0)
        total_pnl = g.get("total_pnl", 0.0)
        daily_pnl = g.get("daily_pnl", 0.0)
        daily_trades = g.get("daily_trades", 0)
        trading_days = g.get("trading_days", 0)
        dd_used = g.get("drawdown_used", 0.0)
        dd_remaining = g.get("drawdown_remaining", 0.0)
        profit_remaining = g.get("profit_target_remaining", 0.0)
        state = g.get("state", "UNKNOWN")
        reason = g.get("reason", "") or "—"
        consistency_ok = g.get("consistency_ok", True)

        lines = [
            "=" * 60,
            f"TradeDay Futures Bot — {ts}",
            "=" * 60,
            f"State            : {state}",
            f"Balance          : ${balance:,.2f}",
            f"Total PnL        : ${total_pnl:+,.2f}",
            f"Daily PnL        : ${daily_pnl:+,.2f}   Trades today: {daily_trades}",
            f"Trading days     : {trading_days}/5",
            f"DD used / left   : ${dd_used:,.2f} / ${dd_remaining:,.2f}",
            f"To profit target : ${profit_remaining:,.2f}",
            f"Consistency OK   : {consistency_ok}",
            f"Reason           : {reason}",
            "-" * 60,
            f"Active strategy  : {active}",
            f"Open positions   : {len(positions)}",
        ]
        for p in positions:
            lines.append(f"   • {p}")
        lines.append("=" * 60)

        try:
            with open(self.dashboard_path, "w") as f:
                f.write("\n".join(lines) + "\n")
        except Exception as e:
            logger.error(f"Failed to write dashboard: {e}")

    def read(self) -> Dict[str, Any]:
        """Read the last written status."""
        try:
            with open(self.output_path) as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return {}
