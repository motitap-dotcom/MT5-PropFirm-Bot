"""Tests for futures_bot.core.notifier.

We don't hit the real Telegram API — we stub `send()` and verify that the
message builders produce well-formed HTML and call the network layer exactly
once per alert. We also verify that disabled / no-credentials notifier is a
no-op, which is the safety guarantee for offline runs.
"""

from __future__ import annotations

from typing import List

import pytest

from futures_bot.core.notifier import TelegramNotifier


class _RecordingNotifier(TelegramNotifier):
    """Test double that captures messages instead of hitting Telegram."""

    def __init__(self, **kwargs):
        super().__init__(token="TOKEN", chat_id="CHAT", enabled=True)
        self.sent: List[str] = []

    async def send(self, message: str, parse_mode: str = "HTML", **kwargs):
        self.sent.append(message)


# ── disabled / missing-credentials guards ──

class TestSendGuards:

    async def test_disabled_is_no_op(self):
        n = TelegramNotifier(token="T", chat_id="C", enabled=False)
        # Should not open a session or raise — just silently return.
        await n.send("hello")
        assert n._session is None

    async def test_missing_token_is_no_op(self):
        n = TelegramNotifier(token="", chat_id="C", enabled=True)
        await n.send("hello")
        assert n._session is None

    async def test_missing_chat_id_is_no_op(self):
        n = TelegramNotifier(token="T", chat_id="", enabled=True)
        await n.send("hello")
        assert n._session is None


# ── Message builders ──

class TestMessageBuilders:

    async def test_trade_opened_includes_all_fields(self):
        n = _RecordingNotifier()
        await n.trade_opened("MESM6", "Buy", 2, 4500.0, 4490.0, 4510.0, "VWAP")
        msg = n.sent[0]
        assert "TRADE OPENED" in msg
        assert "MESM6" in msg
        assert "Buy" in msg
        assert "Contracts: 2" in msg
        assert "4500.00" in msg
        assert "SL: 4490.00" in msg
        assert "TP: 4510.00" in msg
        assert "VWAP" in msg

    async def test_trade_closed_positive_pnl(self):
        n = _RecordingNotifier()
        await n.trade_closed("MESM6", "Buy", 120.50, "TP hit")
        msg = n.sent[0]
        assert "TRADE CLOSED" in msg
        assert "+$120.50" in msg
        assert "TP hit" in msg

    async def test_trade_closed_negative_pnl(self):
        n = _RecordingNotifier()
        await n.trade_closed("MESM6", "Buy", -50.0, "SL hit")
        msg = n.sent[0]
        assert "$-50.00" in msg  # no leading + for losses

    async def test_guardian_alert(self):
        n = _RecordingNotifier()
        await n.guardian_alert("HALTED", "80% drawdown used")
        msg = n.sent[0]
        assert "GUARDIAN ALERT" in msg
        assert "HALTED" in msg
        assert "80% drawdown used" in msg

    async def test_daily_summary(self):
        n = _RecordingNotifier()
        await n.daily_summary({
            "date": "2026-04-22",
            "trades": 3,
            "pnl": 150.0,
            "balance": 50150.0,
            "dd_used": 100.0,
            "trading_days": 2,
            "total_pnl": 150.0,
        })
        msg = n.sent[0]
        assert "DAILY SUMMARY" in msg
        assert "2026-04-22" in msg
        assert "Trades: 3" in msg
        assert "$150.00" in msg
        assert "Trading Days: 2/5" in msg

    async def test_daily_summary_tolerates_missing_fields(self):
        n = _RecordingNotifier()
        # Must not raise even if dict is empty
        await n.daily_summary({})
        assert "DAILY SUMMARY" in n.sent[0]

    async def test_bot_lifecycle_messages(self):
        n = _RecordingNotifier()
        await n.bot_started()
        await n.bot_stopped("Manual stop")
        assert "BOT STARTED" in n.sent[0]
        assert "BOT STOPPED" in n.sent[1]
        assert "Manual stop" in n.sent[1]

    async def test_bot_stopped_default_reason(self):
        n = _RecordingNotifier()
        await n.bot_stopped()
        assert "Manual stop" in n.sent[0]

    async def test_news_alert(self):
        n = _RecordingNotifier()
        await n.news_alert("FOMC Meeting")
        assert "NEWS ALERT" in n.sent[0]
        assert "FOMC Meeting" in n.sent[0]

    async def test_dd_warning_formats_correctly(self):
        n = _RecordingNotifier()
        await n.dd_warning(0.80, 1600.0, 2000.0)
        msg = n.sent[0]
        assert "DRAWDOWN WARNING" in msg
        assert "80%" in msg
        assert "$1600.00" in msg
        assert "$2000.00" in msg

    async def test_heartbeat_is_non_critical(self):
        """Heartbeats should be droppable when rate-limited."""
        n = _RecordingNotifier()
        await n.heartbeat({"state": "ACTIVE", "balance": 50000.0, "daily_pnl": 20.0, "dd_used": 0.0})
        assert "HEARTBEAT" in n.sent[0]


# ── Rate limiter ──

class _MockSession:
    """Stand-in for aiohttp.ClientSession that records posts and returns 200."""

    def __init__(self):
        self.calls = 0

    def post(self, url, json=None):  # noqa: D401
        self.calls += 1
        return _MockResponse()

    async def close(self):
        pass


class _MockResponse:
    status = 200

    async def text(self):
        return "ok"

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        return None


class TestRateLimiter:

    async def test_under_budget_non_critical_sends(self):
        n = TelegramNotifier(token="T", chat_id="C", rate_limit_per_minute=5)
        n._session = _MockSession()
        await n.send("hello", critical=False)
        assert n._session.calls == 1

    async def test_over_budget_non_critical_dropped(self):
        """Once rate budget is exhausted, non-critical messages are dropped."""
        n = TelegramNotifier(token="T", chat_id="C", rate_limit_per_minute=2)
        n._session = _MockSession()
        await n.send("m1", critical=False)
        await n.send("m2", critical=False)
        await n.send("m3", critical=False)
        assert n._session.calls == 2

    async def test_over_budget_critical_still_sends(self):
        """Critical messages must always go through."""
        n = TelegramNotifier(token="T", chat_id="C", rate_limit_per_minute=1)
        n._session = _MockSession()
        await n.send("m1", critical=False)  # fills budget
        await n.send("m2", critical=True)   # must still send
        assert n._session.calls == 2

    async def test_old_timestamps_expire(self):
        """After 60s, stale timestamps should be pruned and budget refreshed."""
        n = TelegramNotifier(token="T", chat_id="C", rate_limit_per_minute=1)
        n._session = _MockSession()
        # Inject a stale timestamp
        n._sent_timestamps.append(0.0)  # from epoch
        assert n._under_rate_limit() is True  # should be pruned


# ── start() / stop() lifecycle ──

class TestLifecycle:

    async def test_stop_without_start_is_safe(self):
        n = TelegramNotifier(token="T", chat_id="C")
        # Should not raise even though _session is None
        await n.stop()
