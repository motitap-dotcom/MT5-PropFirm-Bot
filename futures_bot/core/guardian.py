"""
Guardian - TradeDay Rules Enforcement
The MASTER WATCHDOG that ensures we never violate TradeDay rules.

TradeDay $50K Intraday Evaluation Rules:
  - Max Drawdown: $2,000 (balance cannot drop below $48,000)
  - Profit Target: $3,000
  - Min Trading Days: 5
  - Consistency: No single day > 30% of total profit
  - Position Limit: 5 contracts / 50 micro contracts
  - Intraday only: No overnight positions
  - Restricted trading events: Must flatten before news events
"""

import json
import logging
from dataclasses import dataclass
from enum import IntEnum
from typing import Dict
from datetime import datetime, timezone
from pathlib import Path

logger = logging.getLogger("guardian")

STATE_FILE = Path("status/guardian_state.json")


class GuardianState(IntEnum):
    ACTIVE = 0       # All systems go
    CAUTION = 1      # Approaching limits, reduce risk
    HALTED = 2       # No new trades, manage existing only
    EMERGENCY = 3    # Close everything NOW
    SHUTDOWN = 4     # Permanent stop - evaluation failed or passed


@dataclass
class DailyPnL:
    date: str
    pnl: float
    trades: int


class Guardian:
    """
    Master watchdog for TradeDay rule compliance.
    Checks are run BEFORE every trade and continuously during the session.
    State is persisted to disk so restarts don't lose safety data.
    """

    def __init__(self, config: dict):
        # TradeDay account rules
        self.initial_balance: float = config.get("initial_balance", 50000.0)
        self.max_drawdown: float = config.get("max_drawdown", 2000.0)
        self.profit_target: float = config.get("profit_target", 3000.0)
        self.min_trading_days: int = config.get("min_trading_days", 5)
        self.consistency_pct: float = config.get("consistency_pct", 0.30)
        self.max_contracts: int = config.get("max_contracts", 5)
        self.max_micro_contracts: int = config.get("max_micro_contracts", 50)

        # Safety buffers (don't wait until the last dollar)
        self.dd_warning_pct: float = config.get("dd_warning_pct", 0.60)
        self.dd_critical_pct: float = config.get("dd_critical_pct", 0.80)
        self.dd_emergency_pct: float = config.get("dd_emergency_pct", 0.90)

        # Daily limits
        self.max_daily_loss: float = config.get("max_daily_loss", 400.0)
        self.max_daily_profit: float = config.get("max_daily_profit", 900.0)
        self.max_daily_trades: int = config.get("max_daily_trades", 6)

        # State - loaded from disk if available
        self.state: GuardianState = GuardianState.ACTIVE
        self.current_balance: float = self.initial_balance
        self.min_balance: float = self.initial_balance - self.max_drawdown
        self.daily_pnl: float = 0.0
        self.daily_trades: int = 0
        self.total_pnl: float = 0.0
        self.daily_history: list[DailyPnL] = []
        self.trading_days: int = 0
        self.reason: str = ""

        self._load_state()

    def _save_state(self):
        """Persist guardian state to disk. Called after every state change."""
        try:
            STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
            data = {
                "state": self.state.value,
                "current_balance": self.current_balance,
                "daily_pnl": self.daily_pnl,
                "daily_trades": self.daily_trades,
                "total_pnl": self.total_pnl,
                "trading_days": self.trading_days,
                "reason": self.reason,
                "daily_history": [
                    {"date": d.date, "pnl": d.pnl, "trades": d.trades}
                    for d in self.daily_history
                ],
                "saved_at": datetime.now(timezone.utc).isoformat(),
            }
            # Atomic write: write to temp file then rename
            tmp = STATE_FILE.with_suffix(".tmp")
            tmp.write_text(json.dumps(data, indent=2))
            tmp.rename(STATE_FILE)
        except Exception as e:
            logger.error(f"Failed to save guardian state: {e}")

    def _load_state(self):
        """Load guardian state from disk on startup."""
        try:
            if not STATE_FILE.exists():
                logger.info("No saved guardian state, starting fresh")
                return
            data = json.loads(STATE_FILE.read_text())
            saved_at = data.get("saved_at", "")
            logger.info(f"Loading guardian state from {saved_at}")

            self.state = GuardianState(data.get("state", 0))
            self.current_balance = data.get("current_balance", self.initial_balance)
            self.daily_pnl = data.get("daily_pnl", 0.0)
            self.daily_trades = data.get("daily_trades", 0)
            self.total_pnl = data.get("total_pnl", 0.0)
            self.trading_days = data.get("trading_days", 0)
            self.reason = data.get("reason", "")
            self.daily_history = [
                DailyPnL(date=d["date"], pnl=d["pnl"], trades=d["trades"])
                for d in data.get("daily_history", [])
            ]
            logger.info(f"Guardian restored: state={self.state.name}, "
                        f"daily_pnl=${self.daily_pnl:.2f}, "
                        f"daily_trades={self.daily_trades}, "
                        f"total_pnl=${self.total_pnl:.2f}")
        except Exception as e:
            logger.error(f"Failed to load guardian state: {e}, starting fresh")

    def update_balance(self, current_balance: float, unrealized_pnl: float = 0.0):
        """Update current balance and check all rules."""
        self.current_balance = current_balance
        effective_balance = current_balance + unrealized_pnl
        self.total_pnl = effective_balance - self.initial_balance

        dd_used = self.initial_balance - effective_balance
        dd_pct = dd_used / self.max_drawdown if self.max_drawdown > 0 else 0

        # Check drawdown levels
        if effective_balance <= self.min_balance:
            self._set_state(GuardianState.SHUTDOWN,
                           f"MAX DRAWDOWN BREACHED! Balance ${effective_balance:.2f} <= ${self.min_balance:.2f}")
        elif dd_pct >= self.dd_emergency_pct:
            self._set_state(GuardianState.EMERGENCY,
                           f"EMERGENCY: {dd_pct*100:.1f}% of max DD used (${dd_used:.2f}/${self.max_drawdown:.2f})")
        elif dd_pct >= self.dd_critical_pct:
            self._set_state(GuardianState.HALTED,
                           f"HALTED: {dd_pct*100:.1f}% of max DD used")
        elif dd_pct >= self.dd_warning_pct:
            self._set_state(GuardianState.CAUTION,
                           f"CAUTION: {dd_pct*100:.1f}% of max DD used")
        elif self.state not in (GuardianState.SHUTDOWN,):
            self._set_state(GuardianState.ACTIVE, "")

        # Check if profit target reached
        if self.total_pnl >= self.profit_target and self.trading_days >= self.min_trading_days:
            if self._check_consistency():
                self._set_state(GuardianState.SHUTDOWN,
                               f"EVALUATION PASSED! Profit ${self.total_pnl:.2f} >= ${self.profit_target:.2f}")

        self._save_state()

    def can_open_trade(self, num_contracts: int = 1, is_micro: bool = True) -> tuple[bool, str]:
        """Check if a new trade is allowed."""
        if self.state >= GuardianState.HALTED:
            return False, f"Trading halted: {self.reason}"

        if self.daily_pnl <= -self.max_daily_loss:
            return False, f"Daily loss limit reached: ${self.daily_pnl:.2f}"

        if self.daily_pnl >= self.max_daily_profit:
            return False, f"Daily profit limit reached: ${self.daily_pnl:.2f} (consistency rule)"

        if self.daily_trades >= self.max_daily_trades:
            return False, f"Max daily trades reached: {self.daily_trades}"

        limit = self.max_micro_contracts if is_micro else self.max_contracts
        if num_contracts > limit:
            return False, f"Contract limit exceeded: {num_contracts} > {limit}"

        if self.state == GuardianState.CAUTION:
            return True, "CAUTION: Reduce position size"

        return True, "OK"

    def record_trade(self, pnl: float):
        """Record a completed trade's PnL."""
        self.daily_pnl += pnl
        self.daily_trades += 1
        self.total_pnl += pnl
        self._save_state()

    def start_new_day(self, date_str: str):
        """Reset daily counters for a new trading day."""
        if self.daily_trades > 0:
            self.daily_history.append(DailyPnL(
                date=date_str,
                pnl=self.daily_pnl,
                trades=self.daily_trades,
            ))
            self.trading_days += 1

        self.daily_pnl = 0.0
        self.daily_trades = 0

        if self.state != GuardianState.SHUTDOWN:
            self.state = GuardianState.ACTIVE
            self.reason = ""

        self._save_state()
        logger.info(f"New day started. Trading days: {self.trading_days}, "
                     f"Total PnL: ${self.total_pnl:.2f}")

    def must_close_all(self) -> bool:
        """Returns True if all positions must be closed immediately."""
        return self.state >= GuardianState.EMERGENCY

    def is_evaluation_passed(self) -> bool:
        return (
            self.total_pnl >= self.profit_target and
            self.trading_days >= self.min_trading_days and
            self._check_consistency()
        )

    def _check_consistency(self) -> bool:
        """Check the 30% consistency rule."""
        if not self.daily_history or self.total_pnl <= 0:
            return True
        for day in self.daily_history:
            if day.pnl > 0 and day.pnl / self.total_pnl > self.consistency_pct:
                logger.warning(
                    f"Consistency rule violation: {day.date} PnL=${day.pnl:.2f} "
                    f"= {day.pnl/self.total_pnl*100:.1f}% of total"
                )
                return False
        return True

    def get_max_risk_per_trade(self) -> float:
        """Get maximum allowed risk based on current state."""
        base_risk = 150.0
        if self.state == GuardianState.CAUTION:
            return base_risk * 0.5
        elif self.state == GuardianState.HALTED:
            return 0.0
        else:
            remaining = self.max_daily_loss + self.daily_pnl
            return min(base_risk, max(remaining, 0))

    def get_status(self) -> Dict:
        """Get full guardian status for logging/dashboard."""
        dd_used = max(0, self.initial_balance - self.current_balance)
        return {
            "state": self.state.name,
            "balance": self.current_balance,
            "total_pnl": self.total_pnl,
            "daily_pnl": self.daily_pnl,
            "daily_trades": self.daily_trades,
            "trading_days": self.trading_days,
            "drawdown_used": dd_used,
            "drawdown_remaining": self.max_drawdown - dd_used,
            "profit_target_remaining": self.profit_target - self.total_pnl,
            "consistency_ok": self._check_consistency(),
            "reason": self.reason,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

    def _set_state(self, new_state: GuardianState, reason: str):
        """Update guardian state with logging."""
        if new_state != self.state:
            old = self.state.name
            self.state = new_state
            self.reason = reason
            logger.warning(f"Guardian state: {old} -> {new_state.name}: {reason}")
