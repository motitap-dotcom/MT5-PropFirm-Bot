"""Tests for futures_bot.core.tradovate_client — pure / deterministic parts only.

Network, WebSocket, Playwright and persistence paths are intentionally NOT
covered here; they belong to integration tests. This file exercises:
  - _encrypt_password (deterministic password obfuscation)
  - _compute_hmac (deterministic HMAC-SHA256 with known key)
  - _parse_expiry (ISO8601 -> epoch)
  - _save_token / _load_saved_token / _load_any_saved_token (file round-trip)
  - _process_md_message (JSON frame parsing + callback dispatch)
"""

from __future__ import annotations

import base64
import hashlib
import hmac as _hmac
import importlib
import json
import time
from pathlib import Path

import pytest

from futures_bot.core import tradovate_client as tc_mod
from futures_bot.core.tradovate_client import (
    TradovateClient,
    _compute_hmac,
    _encrypt_password,
)


# ── _encrypt_password ──

class TestEncryptPassword:

    def test_deterministic(self):
        assert _encrypt_password("alice", "hunter2") == _encrypt_password("alice", "hunter2")

    def test_produces_valid_base64(self):
        out = _encrypt_password("alice", "hunter2")
        # Should decode without error
        base64.b64decode(out)

    def test_known_vector(self):
        """Mirror the algorithm in the test to lock the implementation."""
        name, password = "alice", "hunter2"
        offset = len(name) % len(password)           # 5 % 7 = 5
        expected = base64.b64encode(
            (password[offset:] + password[:offset])[::-1].encode()
        ).decode()
        assert _encrypt_password(name, password) == expected

    def test_different_name_yields_different_result(self):
        assert _encrypt_password("alice", "secret!!") != _encrypt_password("bob", "secret!!")

    def test_different_password_yields_different_result(self):
        assert _encrypt_password("alice", "secretA!") != _encrypt_password("alice", "secretB!")


# ── _compute_hmac ──

class TestComputeHMAC:

    def test_known_vector(self):
        """Lock HMAC computation: only chl+deviceId+name+password+appId, in order."""
        payload = {
            "chl": "",
            "deviceId": "dev-123",
            "name": "alice",
            "password": "ENC",
            "appId": "tradovate_trader(web)",
            "appVersion": "3.260220.0",     # must NOT be included
            "cid": 8,                          # must NOT be included
            "sec": "",                         # must NOT be included
            "organization": "",                # must NOT be included
        }
        msg = "dev-123aliceENCtradovate_trader(web)"  # chl("")+rest
        expected = _hmac.new(
            b"1259-11e7-485a-aeae-9b6016579351",
            msg.encode(),
            hashlib.sha256,
        ).hexdigest()
        assert _compute_hmac(payload) == expected

    def test_missing_fields_substituted_with_empty(self):
        """Absent fields should not raise — should coerce to empty string."""
        out = _compute_hmac({"name": "alice"})
        assert isinstance(out, str)
        assert len(out) == 64  # SHA256 hex

    def test_order_sensitivity(self):
        """Swapping name <-> password must change the HMAC (tests field order)."""
        a = _compute_hmac({
            "chl": "", "deviceId": "d", "name": "alice", "password": "pw",
            "appId": "app",
        })
        b = _compute_hmac({
            "chl": "", "deviceId": "d", "name": "pw", "password": "alice",
            "appId": "app",
        })
        assert a != b


# ── _parse_expiry ──

def _make_client():
    return TradovateClient(username="u", password="p", live=False)


class TestParseExpiry:

    def test_iso_with_z_suffix(self):
        c = _make_client()
        c._parse_expiry("2026-01-01T00:00:00Z")
        # Jan 1 2026 UTC epoch
        assert c.token_expiry == pytest.approx(1767225600.0)

    def test_iso_with_offset(self):
        c = _make_client()
        c._parse_expiry("2026-01-01T00:00:00+00:00")
        assert c.token_expiry == pytest.approx(1767225600.0)

    def test_iso_with_microseconds(self):
        c = _make_client()
        c._parse_expiry("2026-01-01T00:00:00.123456+00:00")
        # Accepted; some fractional epoch value
        assert c.token_expiry > 1767225600.0
        assert c.token_expiry < 1767225601.0

    def test_empty_string_defaults_to_24h(self):
        c = _make_client()
        before = time.time()
        c._parse_expiry("")
        after = time.time()
        assert before + 86400 - 1 <= c.token_expiry <= after + 86400 + 1

    def test_invalid_string_defaults_to_24h(self):
        c = _make_client()
        before = time.time()
        c._parse_expiry("not-a-date")
        after = time.time()
        assert before + 86400 - 1 <= c.token_expiry <= after + 86400 + 1


# ── _save_token / _load_saved_token / _load_any_saved_token ──

class TestTokenPersistence:

    def test_save_and_load_round_trip(self, tmp_path, monkeypatch):
        """Write a token via _save_token, then read it back."""
        fake_path = tmp_path / ".tradovate_token.json"
        monkeypatch.setattr(tc_mod, "TOKEN_FILE", fake_path)
        # Isolate .env write: point BOT_ROOT at a dir with no .env
        monkeypatch.setenv("BOT_ROOT", str(tmp_path))

        c = _make_client()
        c.access_token = "abc123"
        c.md_access_token = "md123"
        c.token_expiry = time.time() + 3600
        c._save_token()
        assert fake_path.exists()

        data = json.loads(fake_path.read_text())
        assert data["access_token"] == "abc123"
        assert data["md_access_token"] == "md123"

        c2 = _make_client()
        loaded = c2._load_saved_token()
        assert loaded is True
        assert c2.access_token == "abc123"
        assert c2.md_access_token == "md123"

    def test_load_saved_token_rejects_expired(self, tmp_path, monkeypatch):
        fake_path = tmp_path / ".tradovate_token.json"
        monkeypatch.setattr(tc_mod, "TOKEN_FILE", fake_path)
        fake_path.write_text(json.dumps({
            "access_token": "stale",
            "md_access_token": "stale_md",
            "expiry": time.time() - 3600,  # expired 1h ago
        }))
        c = _make_client()
        assert c._load_saved_token() is False

    def test_load_any_saved_token_returns_expired_tokens(self, tmp_path, monkeypatch):
        """For renewal attempts, we must return even expired tokens."""
        fake_path = tmp_path / ".tradovate_token.json"
        monkeypatch.setattr(tc_mod, "TOKEN_FILE", fake_path)
        fake_path.write_text(json.dumps({
            "access_token": "stale",
            "md_access_token": "stale_md",
            "expiry": time.time() - 3600,
        }))
        c = _make_client()
        tok, md, exp = c._load_any_saved_token()
        assert tok == "stale"
        assert md == "stale_md"

    def test_load_saved_token_missing_file_returns_false(self, tmp_path, monkeypatch):
        monkeypatch.setattr(tc_mod, "TOKEN_FILE", tmp_path / "nonexistent.json")
        c = _make_client()
        assert c._load_saved_token() is False

    def test_load_any_saved_token_missing_file(self, tmp_path, monkeypatch):
        monkeypatch.setattr(tc_mod, "TOKEN_FILE", tmp_path / "nonexistent.json")
        c = _make_client()
        tok, md, exp = c._load_any_saved_token()
        assert tok is None
        assert md is None
        assert exp == 0

    def test_load_saved_token_corrupt_file(self, tmp_path, monkeypatch):
        fake_path = tmp_path / ".tradovate_token.json"
        fake_path.write_text("{ not valid json")
        monkeypatch.setattr(tc_mod, "TOKEN_FILE", fake_path)
        c = _make_client()
        assert c._load_saved_token() is False


# ── _process_md_message (market data parser + callback dispatch) ──

class TestProcessMdMessage:

    def test_invalid_json_silently_ignored(self):
        c = _make_client()
        c._process_md_message("{not json")  # should not raise

    def test_empty_list_no_callbacks(self):
        c = _make_client()
        called = []
        c._callbacks["MESM6"] = [lambda d: called.append(d)]
        c._process_md_message("[]")
        assert called == []

    def test_md_event_dispatches_to_callbacks(self):
        c = _make_client()
        received = []
        c._callbacks["MESM6"] = [lambda d: received.append(d)]
        msg = json.dumps([{"e": "md", "d": {"contractId": 1, "bid": 4500.0}}])
        c._process_md_message(msg)
        assert len(received) == 1
        assert received[0]["bid"] == 4500.0

    def test_frame_with_bid_field_dispatched_even_without_event_key(self):
        c = _make_client()
        received = []
        c._callbacks["MESM6"] = [lambda d: received.append(d)]
        # No "e" key, but has "bid" -> still dispatches
        msg = json.dumps([{"contractId": 1, "bid": 4500.0}])
        c._process_md_message(msg)
        assert received == [{"contractId": 1, "bid": 4500.0}]

    def test_unrelated_event_not_dispatched(self):
        c = _make_client()
        received = []
        c._callbacks["MESM6"] = [lambda d: received.append(d)]
        # No bid / trade / e=="md"
        msg = json.dumps([{"e": "chart", "d": {"unrelated": True}}])
        c._process_md_message(msg)
        assert received == []

    def test_callback_exception_isolated(self):
        c = _make_client()
        good_calls = []

        def bad_cb(data):
            raise RuntimeError("boom")

        def good_cb(data):
            good_calls.append(data)

        c._callbacks["MESM6"] = [bad_cb, good_cb]
        msg = json.dumps([{"e": "md", "d": {"contractId": 1, "bid": 1.0}}])
        c._process_md_message(msg)  # must not raise
        assert len(good_calls) == 1

    def test_single_object_wrapped_as_list(self):
        """If the server sends a bare dict instead of a list, still handled."""
        c = _make_client()
        received = []
        c._callbacks["MESM6"] = [lambda d: received.append(d)]
        msg = json.dumps({"e": "md", "d": {"contractId": 1, "bid": 4500.0}})
        c._process_md_message(msg)
        assert len(received) == 1
