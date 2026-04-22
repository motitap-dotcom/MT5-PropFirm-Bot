"""Tests for futures_bot.core.status_writer."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from futures_bot.core.status_writer import StatusWriter


class TestStatusWriter:

    def test_write_creates_file_and_parents(self, tmp_path):
        out = tmp_path / "nested" / "status.json"
        sw = StatusWriter(str(out))
        sw.write(guardian_status={"state": "ACTIVE"})
        assert out.exists()
        data = json.loads(out.read_text())
        assert data["guardian"]["state"] == "ACTIVE"
        assert data["bot"] == "TradeDay Futures Bot"
        assert data["platform"] == "Tradovate"

    def test_write_includes_timestamp_and_empty_defaults(self, tmp_path):
        out = tmp_path / "status.json"
        sw = StatusWriter(str(out))
        sw.write(guardian_status={})
        data = json.loads(out.read_text())
        assert "timestamp" in data
        assert data["positions"] == []
        assert data["risk"] == {}

    def test_write_merges_extra_dict(self, tmp_path):
        out = tmp_path / "status.json"
        sw = StatusWriter(str(out))
        sw.write(guardian_status={}, extra={"active_strategy": {"MES": "vwap"}})
        data = json.loads(out.read_text())
        assert data["active_strategy"] == {"MES": "vwap"}

    def test_read_round_trip(self, tmp_path):
        out = tmp_path / "status.json"
        sw = StatusWriter(str(out))
        sw.write(
            guardian_status={"state": "CAUTION"},
            risk_status={"open_positions": 2},
            positions=[{"symbol": "MESM6", "net": 1}],
        )
        result = sw.read()
        assert result["guardian"]["state"] == "CAUTION"
        assert result["risk"]["open_positions"] == 2
        assert result["positions"][0]["symbol"] == "MESM6"

    def test_read_missing_file_returns_empty(self, tmp_path):
        sw = StatusWriter(str(tmp_path / "does_not_exist.json"))
        assert sw.read() == {}

    def test_read_corrupt_file_returns_empty(self, tmp_path):
        out = tmp_path / "status.json"
        out.write_text("{ not valid json")
        sw = StatusWriter(str(out))
        assert sw.read() == {}

    def test_write_overwrites_previous(self, tmp_path):
        out = tmp_path / "status.json"
        sw = StatusWriter(str(out))
        sw.write(guardian_status={"state": "ACTIVE"})
        sw.write(guardian_status={"state": "CAUTION"})
        assert sw.read()["guardian"]["state"] == "CAUTION"
