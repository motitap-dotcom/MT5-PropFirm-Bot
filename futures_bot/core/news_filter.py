"""
News Filter - TradeDay Restricted Trading Events
Blocks trading before/during/after high-impact economic events.

TradeDay requires flattening positions before certain news events.
This module loads the restricted events calendar and enforces it.
"""

import logging
import json
from dataclasses import dataclass
from datetime import datetime, time, timedelta, timezone
from typing import List, Optional
from pathlib import Path

logger = logging.getLogger("news_filter")

EDT_OFFSET = timedelta(hours=-4)
EST_OFFSET = timedelta(hours=-5)


@dataclass
class NewsEvent:
    date: str          # YYYY-MM-DD
    time_et: str       # HH:MM (ET)
    name: str
    applies_to: str    # "all" or "energy"
    buffer_minutes_before: int = 30
    buffer_minutes_after: int = 15


class NewsFilter:
    """Filters trading around TradeDay restricted events."""

    def __init__(self, config_path: str = "configs/restricted_events.json"):
        self.events: List[NewsEvent] = []
        self.flatten_buffer_minutes: int = 30  # Flatten 30 min before
        self.no_trade_after_minutes: int = 15  # No new trades 15 min after
        self._load_events(config_path)

    def _load_events(self, path: str):
        """Load restricted events from JSON config."""
        try:
            with open(path, "r") as f:
                data = json.load(f)
            for evt in data.get("events", []):
                self.events.append(NewsEvent(
                    date=evt["date"],
                    time_et=evt["time"],
                    name=evt["name"],
                    applies_to=evt.get("applies_to", "all"),
                    buffer_minutes_before=evt.get("buffer_before", 30),
                    buffer_minutes_after=evt.get("buffer_after", 15),
                ))
            logger.info(f"Loaded {len(self.events)} restricted events")
        except FileNotFoundError:
            logger.warning(f"No restricted events file found at {path}")
        except Exception as e:
            logger.error(f"Error loading restricted events: {e}")

    def is_restricted(self, symbols: List[str] = None) -> "tuple[bool, Optional[str]]":
        """
        Check if trading is currently restricted due to a news event.

        Args:
            symbols: List of symbols being traded (to check energy-specific events)

        Returns:
            (is_restricted, event_name)
        """
        now_utc = datetime.now(timezone.utc)
        today = now_utc.strftime("%Y-%m-%d")

        is_energy = symbols and any(
            s.startswith(("CL", "MCL", "NG", "MNG"))
            for s in (symbols or [])
        )

        for event in self.events:
            if event.date != today:
                continue

            # Skip energy-only events if not trading energy
            if event.applies_to == "energy" and not is_energy:
                continue

            # Parse event time
            try:
                hour, minute = map(int, event.time_et.split(":"))
                event_dt = datetime.strptime(event.date, "%Y-%m-%d")
                # Assume EDT for simplicity (March-November)
                month = event_dt.month
                offset = EDT_OFFSET if 3 <= month <= 11 else EST_OFFSET
                event_utc = event_dt.replace(
                    hour=hour, minute=minute,
                    tzinfo=timezone.utc
                ) - offset

                buffer_before = timedelta(minutes=event.buffer_minutes_before)
                buffer_after = timedelta(minutes=event.buffer_minutes_after)

                if event_utc - buffer_before <= now_utc <= event_utc + buffer_after:
                    logger.warning(f"Trading restricted: {event.name} at {event.time_et} ET")
                    return True, event.name

            except (ValueError, TypeError) as e:
                logger.error(f"Error parsing event time: {e}")
                continue

        return False, None

    def must_flatten_for_event(self, symbols: List[str] = None) -> "tuple[bool, Optional[str]]":
        """
        Check if we need to flatten positions for an upcoming event.
        Returns True if an event is within flatten_buffer_minutes.
        """
        now_utc = datetime.now(timezone.utc)
        today = now_utc.strftime("%Y-%m-%d")

        is_energy = symbols and any(
            s.startswith(("CL", "MCL", "NG", "MNG"))
            for s in (symbols or [])
        )

        for event in self.events:
            if event.date != today:
                continue
            if event.applies_to == "energy" and not is_energy:
                continue

            try:
                hour, minute = map(int, event.time_et.split(":"))
                event_dt = datetime.strptime(event.date, "%Y-%m-%d")
                month = event_dt.month
                offset = EDT_OFFSET if 3 <= month <= 11 else EST_OFFSET
                event_utc = event_dt.replace(
                    hour=hour, minute=minute,
                    tzinfo=timezone.utc
                ) - offset

                flatten_time = event_utc - timedelta(minutes=self.flatten_buffer_minutes)
                if flatten_time <= now_utc < event_utc:
                    return True, event.name

            except (ValueError, TypeError):
                continue

        return False, None

    def get_next_event(self) -> Optional[NewsEvent]:
        """Get the next upcoming restricted event."""
        now_utc = datetime.now(timezone.utc)
        today = now_utc.strftime("%Y-%m-%d")

        for event in self.events:
            if event.date >= today:
                return event
        return None
