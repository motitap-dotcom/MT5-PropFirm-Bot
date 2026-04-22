"""Tests for futures_bot.core.news_filter — restricted events filter."""

from __future__ import annotations

import pytest
from freezegun import freeze_time

from futures_bot.core.news_filter import NewsFilter


# ── Loading ──

class TestLoadingEvents:

    def test_loads_events_from_file(self, events_file):
        path = events_file([
            {"date": "2026-06-15", "time": "8:30", "name": "CPI",
             "applies_to": "all", "buffer_before": 30, "buffer_after": 15},
        ])
        nf = NewsFilter(path)
        assert len(nf.events) == 1
        assert nf.events[0].name == "CPI"
        assert nf.events[0].buffer_minutes_before == 30

    def test_missing_file_handled_gracefully(self, tmp_path):
        nf = NewsFilter(str(tmp_path / "does_not_exist.json"))
        assert nf.events == []

    def test_applies_default_buffers(self, events_file):
        path = events_file([
            {"date": "2026-06-15", "time": "8:30", "name": "CPI"},
        ])
        nf = NewsFilter(path)
        assert nf.events[0].buffer_minutes_before == 30
        assert nf.events[0].buffer_minutes_after == 15


# ── is_restricted ── (June = EDT, UTC-4; Jan = EST, UTC-5)

class TestIsRestricted:

    @freeze_time("2026-06-15 12:10:00")  # 08:10 ET, CPI at 08:30, buffer 30m before
    def test_within_buffer_before_event(self, events_file):
        path = events_file([
            {"date": "2026-06-15", "time": "8:30", "name": "CPI",
             "applies_to": "all"},
        ])
        nf = NewsFilter(path)
        restricted, name = nf.is_restricted(symbols=["MESM6"])
        assert restricted is True
        assert name == "CPI"

    @freeze_time("2026-06-15 12:40:00")  # 08:40 ET, 10 min after event, within 15m after
    def test_within_buffer_after_event(self, events_file):
        path = events_file([
            {"date": "2026-06-15", "time": "8:30", "name": "CPI",
             "applies_to": "all"},
        ])
        nf = NewsFilter(path)
        restricted, _ = nf.is_restricted(symbols=["MESM6"])
        assert restricted is True

    @freeze_time("2026-06-15 13:00:00")  # 09:00 ET, 30 min after, outside buffer
    def test_outside_buffer_after_event(self, events_file):
        path = events_file([
            {"date": "2026-06-15", "time": "8:30", "name": "CPI",
             "applies_to": "all"},
        ])
        nf = NewsFilter(path)
        restricted, _ = nf.is_restricted(symbols=["MESM6"])
        assert restricted is False

    @freeze_time("2026-06-15 11:00:00")  # 07:00 ET, 90 min before
    def test_well_before_event_not_restricted(self, events_file):
        path = events_file([
            {"date": "2026-06-15", "time": "8:30", "name": "CPI",
             "applies_to": "all"},
        ])
        nf = NewsFilter(path)
        restricted, _ = nf.is_restricted(symbols=["MESM6"])
        assert restricted is False

    @freeze_time("2026-06-16 12:10:00")  # Day after
    def test_different_day_not_restricted(self, events_file):
        path = events_file([
            {"date": "2026-06-15", "time": "8:30", "name": "CPI",
             "applies_to": "all"},
        ])
        nf = NewsFilter(path)
        restricted, _ = nf.is_restricted(symbols=["MESM6"])
        assert restricted is False

    @freeze_time("2026-06-15 13:10:00")  # 09:10 ET, EIA restricted
    def test_energy_event_blocks_crude_symbols(self, events_file):
        path = events_file([
            {"date": "2026-06-15", "time": "9:30", "name": "EIA",
             "applies_to": "energy"},
        ])
        nf = NewsFilter(path)
        restricted, name = nf.is_restricted(symbols=["MCLM6"])
        assert restricted is True
        assert name == "EIA"

    @freeze_time("2026-06-15 13:10:00")
    def test_energy_event_does_not_block_equity(self, events_file):
        path = events_file([
            {"date": "2026-06-15", "time": "9:30", "name": "EIA",
             "applies_to": "energy"},
        ])
        nf = NewsFilter(path)
        restricted, _ = nf.is_restricted(symbols=["MESM6"])
        assert restricted is False

    @freeze_time("2026-06-15 13:10:00")
    def test_all_applies_blocks_all_symbols(self, events_file):
        path = events_file([
            {"date": "2026-06-15", "time": "9:30", "name": "FOMC",
             "applies_to": "all"},
        ])
        nf = NewsFilter(path)
        restricted, _ = nf.is_restricted(symbols=["MESM6"])
        assert restricted is True
        restricted, _ = nf.is_restricted(symbols=["MCLM6"])
        assert restricted is True

    @freeze_time("2026-01-15 13:10:00")  # 08:10 ET (EST, UTC-5), 20 min before 08:30 event
    def test_est_timezone_respected_in_winter(self, events_file):
        path = events_file([
            {"date": "2026-01-15", "time": "8:30", "name": "CPI",
             "applies_to": "all"},
        ])
        nf = NewsFilter(path)
        restricted, _ = nf.is_restricted(symbols=["MESM6"])
        assert restricted is True

    @freeze_time("2026-03-02 13:10:00")  # Pre-DST; EST (UTC-5) -> 08:10 ET
    def test_early_march_uses_est_not_edt(self, events_file):
        """Regression: early March is EST. 08:30 ET event = 13:30 UTC.
        With buggy month-based DST this would be computed as 12:30 UTC and
        the window would not match at 13:10 UTC."""
        path = events_file([
            {"date": "2026-03-02", "time": "8:30", "name": "CPI",
             "applies_to": "all"},
        ])
        nf = NewsFilter(path)
        restricted, _ = nf.is_restricted(symbols=["MESM6"])
        assert restricted is True

    @freeze_time("2026-11-30 13:10:00")  # Post-DST; EST (UTC-5) -> 08:10 ET
    def test_late_november_uses_est_not_edt(self, events_file):
        path = events_file([
            {"date": "2026-11-30", "time": "8:30", "name": "CPI",
             "applies_to": "all"},
        ])
        nf = NewsFilter(path)
        restricted, _ = nf.is_restricted(symbols=["MESM6"])
        assert restricted is True


# ── must_flatten_for_event ──

class TestMustFlattenForEvent:

    @freeze_time("2026-06-15 12:10:00")  # 08:10 ET, 20 min before event, within flatten buffer (30m)
    def test_within_flatten_buffer(self, events_file):
        path = events_file([
            {"date": "2026-06-15", "time": "8:30", "name": "CPI",
             "applies_to": "all"},
        ])
        nf = NewsFilter(path)
        must, name = nf.must_flatten_for_event(symbols=["MESM6"])
        assert must is True
        assert name == "CPI"

    @freeze_time("2026-06-15 12:35:00")  # 08:35 ET, past the event start
    def test_after_event_not_flatten(self, events_file):
        path = events_file([
            {"date": "2026-06-15", "time": "8:30", "name": "CPI",
             "applies_to": "all"},
        ])
        nf = NewsFilter(path)
        must, _ = nf.must_flatten_for_event(symbols=["MESM6"])
        assert must is False

    @freeze_time("2026-06-15 11:30:00")  # 07:30 ET, 60 min before, outside 30m flatten buffer
    def test_before_flatten_buffer(self, events_file):
        path = events_file([
            {"date": "2026-06-15", "time": "8:30", "name": "CPI",
             "applies_to": "all"},
        ])
        nf = NewsFilter(path)
        must, _ = nf.must_flatten_for_event(symbols=["MESM6"])
        assert must is False


# ── get_next_event ──

class TestGetNextEvent:

    @freeze_time("2026-06-14 12:00:00")
    def test_returns_first_future_event(self, events_file):
        path = events_file([
            {"date": "2026-06-15", "time": "8:30", "name": "CPI"},
            {"date": "2026-06-20", "time": "14:00", "name": "FOMC"},
        ])
        nf = NewsFilter(path)
        evt = nf.get_next_event()
        assert evt is not None
        assert evt.name == "CPI"

    @freeze_time("2026-07-01 12:00:00")
    def test_no_future_events_returns_none(self, events_file):
        path = events_file([
            {"date": "2026-06-15", "time": "8:30", "name": "CPI"},
        ])
        nf = NewsFilter(path)
        assert nf.get_next_event() is None


# ── Malformed data ──

class TestMalformed:

    def test_bad_time_string_is_skipped(self, events_file, caplog):
        path = events_file([
            {"date": "2026-06-15", "time": "not-a-time", "name": "Bad",
             "applies_to": "all"},
            {"date": "2026-06-15", "time": "8:30", "name": "Good",
             "applies_to": "all"},
        ])
        nf = NewsFilter(path)
        with freeze_time("2026-06-15 12:10:00"):
            restricted, name = nf.is_restricted(symbols=["MESM6"])
        assert restricted is True
        assert name == "Good"
