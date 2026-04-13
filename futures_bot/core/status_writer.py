"""
Status Writer - Writes bot status to JSON file for monitoring.
"""

import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Any

logger = logging.getLogger("status_writer")


class StatusWriter:
    """Writes periodic status snapshots for external monitoring."""

    def __init__(self, output_path: str = "status/status.json"):
        self.output_path = Path(output_path)
        self.output_path.parent.mkdir(parents=True, exist_ok=True)

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

    def read(self) -> Dict[str, Any]:
        """Read the last written status."""
        try:
            with open(self.output_path) as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return {}
