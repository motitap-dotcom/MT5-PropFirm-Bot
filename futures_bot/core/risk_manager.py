"""
Risk Manager - Position sizing, session management, and trade validation.

Manages:
  - Position sizing based on risk per trade and stop distance
  - Trading session windows (9:30-15:30 ET)
  - End of day flatten
  - Contract-specific tick values
"""

import logging
from dataclasses import dataclass
from typing import Dict, Optional, Tuple
from datetime import datetime, time, timezone, timedelta

logger = logging.getLogger("risk_manager")

# US Eastern timezone offset (simplified - doesn't handle DST perfectly)
ET_OFFSET = timedelta(hours=-5)  # EST
EDT_OFFSET = timedelta(hours=-4)  # EDT


@dataclass
class ContractSpec:
    """Specification for a futures contract."""
    symbol: str
    tick_size: float
    tick_value: float  # Dollar value per tick
    margin: float  # Required margin per contract
    point_value: float  # Dollar value per point


# Micro futures contract specifications
CONTRACT_SPECS = {
    "MES": ContractSpec("MES", 0.25, 1.25, 50, 5.0),       # Micro E-mini S&P 500
    "MNQ": ContractSpec("MNQ", 0.25, 0.50, 50, 2.0),       # Micro E-mini Nasdaq
    "MCL": ContractSpec("MCL", 0.01, 1.00, 500, 100.0),     # Micro Crude Oil
    "MGC": ContractSpec("MGC", 0.10, 1.00, 500, 10.0),      # Micro Gold
    "MYM": ContractSpec("MYM", 1.00, 0.50, 50, 0.5),        # Micro E-mini Dow
    "M2K": ContractSpec("M2K", 0.10, 0.50, 50, 5.0),        # Micro E-mini Russell
    # Standard contracts
    "ES": ContractSpec("ES", 0.25, 12.50, 500, 50.0),
    "NQ": ContractSpec("NQ", 0.25, 5.00, 500, 20.0),
    "CL": ContractSpec("CL", 0.01, 10.00, 5000, 1000.0),
    "GC": ContractSpec("GC", 0.10, 10.00, 5000, 100.0),
}


class RiskManager:
    """Manages position sizing, session timing, and trade validation."""

    def __init__(self, config: dict):
        self.max_risk_per_trade: float = config.get("max_risk_per_trade", 150.0)
        self.max_risk_pct: float = config.get("max_risk_pct", 0.003)  # 0.3% of account
        self.max_positions: int = config.get("max_positions", 3)
        self.max_contracts_per_trade: int = config.get("max_contracts_per_trade", 5)

        # Session times (ET)
        self.session_start: time = time(9, 30)   # 9:30 AM ET
        self.session_end: time = time(15, 30)     # 3:30 PM ET
        self.flatten_time: time = time(15, 45)    # 3:45 PM ET - force close
        self.no_new_trades_after: time = time(15, 0)  # 3:00 PM ET

        # Dead zone (low volume lunch)
        self.dead_zone_start: time = time(12, 0)
        self.dead_zone_end: time = time(13, 30)
        self.reduce_in_dead_zone: bool = config.get("reduce_in_dead_zone", True)

        # Current state
        self.open_positions: int = 0
        self.open_contracts: int = 0

    def calculate_position_size(self, symbol: str, stop_distance: float,
                                 max_risk: float = None) -> int:
        """
        Calculate number of contracts based on risk and stop distance.

        Args:
            symbol: Contract symbol (e.g., 'MES', 'MNQ')
            stop_distance: Distance to stop loss in points
            max_risk: Max risk in dollars (overrides default)

        Returns:
            Number of contracts (0 if trade not viable)
        """
        spec = self._get_spec(symbol)
        if not spec:
            logger.error(f"Unknown contract: {symbol}")
            return 0

        risk = max_risk or self.max_risk_per_trade
        risk_per_contract = stop_distance * spec.point_value

        if risk_per_contract <= 0:
            return 0

        contracts = int(risk / risk_per_contract)
        contracts = max(1, min(contracts, self.max_contracts_per_trade))

        # Double check: actual risk with this size
        actual_risk = contracts * risk_per_contract
        if actual_risk > risk * 1.1:  # 10% buffer
            contracts = max(0, contracts - 1)

        logger.debug(f"Position size: {contracts} {symbol} "
                      f"(stop={stop_distance:.2f}pts, risk=${contracts * risk_per_contract:.2f})")
        return contracts

    def is_trading_session(self) -> Tuple[bool, str]:
        """Check if we're in a valid trading session."""
        # Check weekend (futures markets closed Sat-Sun)
        now_utc = datetime.now(timezone.utc)
        month = now_utc.month
        if 3 <= month <= 11:
            now_et_dt = now_utc + EDT_OFFSET
        else:
            now_et_dt = now_utc + ET_OFFSET
        weekday = now_et_dt.weekday()  # 0=Mon, 5=Sat, 6=Sun
        if weekday >= 5:
            return False, f"Weekend (day={weekday}), markets closed"

        now_et = now_et_dt.time()

        if now_et < self.session_start:
            return False, f"Pre-market: {now_et.strftime('%H:%M')} ET (opens {self.session_start})"

        if now_et >= self.no_new_trades_after:
            return False, f"No new trades after {self.no_new_trades_after} ET"

        if now_et >= self.session_end:
            return False, "Session closed"

        if self.reduce_in_dead_zone and self.dead_zone_start <= now_et < self.dead_zone_end:
            return True, "DEAD ZONE: Reduce position size by 50%"

        return True, "Session active"

    def is_dead_zone(self) -> bool:
        """Check if we're in the low-volume lunch period."""
        now_et = self._get_et_time()
        return self.dead_zone_start <= now_et < self.dead_zone_end

    def must_flatten(self) -> bool:
        """Check if we must close all positions (end of day)."""
        now_et = self._get_et_time()
        return now_et >= self.flatten_time

    def can_open_position(self) -> Tuple[bool, str]:
        """Check if we can open a new position."""
        if self.open_positions >= self.max_positions:
            return False, f"Max positions reached: {self.open_positions}/{self.max_positions}"

        in_session, msg = self.is_trading_session()
        if not in_session:
            return False, msg

        return True, "OK"

    def get_risk_multiplier(self) -> float:
        """Get risk multiplier based on current conditions."""
        multiplier = 1.0

        if self.is_dead_zone():
            multiplier *= 0.5  # Half risk during dead zone

        return multiplier

    def calculate_stop_risk_dollars(self, symbol: str, stop_distance: float,
                                     contracts: int) -> float:
        """Calculate the dollar risk for a given setup."""
        spec = self._get_spec(symbol)
        if not spec:
            return 0.0
        return stop_distance * spec.point_value * contracts

    def get_tick_value(self, symbol: str) -> float:
        """Get tick value for a symbol."""
        spec = self._get_spec(symbol)
        return spec.tick_value if spec else 0.0

    def get_point_value(self, symbol: str) -> float:
        """Get point value for a symbol."""
        spec = self._get_spec(symbol)
        return spec.point_value if spec else 0.0

    def _get_spec(self, symbol: str) -> Optional[ContractSpec]:
        """Get contract specification, handling month codes."""
        # Strip month/year code (e.g., 'MESM5' -> 'MES')
        base = symbol
        for spec_name in sorted(CONTRACT_SPECS.keys(), key=len, reverse=True):
            if symbol.startswith(spec_name):
                base = spec_name
                break
        return CONTRACT_SPECS.get(base)

    def _get_et_time(self) -> time:
        """Get current time in US Eastern."""
        now_utc = datetime.now(timezone.utc)
        # Simple DST check: March-November is EDT
        month = now_utc.month
        if 3 <= month <= 11:
            now_et = now_utc + EDT_OFFSET
        else:
            now_et = now_utc + ET_OFFSET
        return now_et.time()

    def get_current_et_hour(self) -> int:
        """Get current hour in ET."""
        return self._get_et_time().hour
