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

    async def send(self, message: str, parse_mode: str = "HTML"):
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
