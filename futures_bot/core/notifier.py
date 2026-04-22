"""
Telegram Notification Module
Sends alerts for trades, guardian state changes, and daily summaries.

Includes a lightweight per-minute rate limiter: non-critical messages (heartbeat)
are dropped when the send budget is exhausted; critical messages (guardian
alerts, trades) are always sent.
"""

import logging
import time as _time
from collections import deque
from typing import Optional
import aiohttp

logger = logging.getLogger("notifier")


class TelegramNotifier:
    """Sends notifications via Telegram Bot API."""

    def __init__(self, token: str, chat_id: str, enabled: bool = True,
                 rate_limit_per_minute: int = 10):
        self.token = token
        self.chat_id = chat_id
        self.enabled = enabled
        self.base_url = f"https://api.telegram.org/bot{token}"
        self._session: Optional[aiohttp.ClientSession] = None
        self._sent_timestamps: deque = deque()
        self.rate_limit_per_minute = max(1, int(rate_limit_per_minute))

    async def start(self):
        self._session = aiohttp.ClientSession()

    async def stop(self):
        if self._session:
            await self._session.close()

    def _under_rate_limit(self) -> bool:
        """Return True if we still have budget in the last 60 seconds."""
        now = _time.time()
        while self._sent_timestamps and now - self._sent_timestamps[0] > 60:
            self._sent_timestamps.popleft()
        return len(self._sent_timestamps) < self.rate_limit_per_minute

    async def send(self, message: str, parse_mode: str = "HTML",
                   critical: bool = True):
        """
        Send a message to Telegram.
        If critical=False and the rate limit is exhausted, the message is dropped.
        Critical messages bypass the limit.
        """
        if not self.enabled or not self.token or not self.chat_id:
            return

        if not critical and not self._under_rate_limit():
            logger.debug("Rate-limited (non-critical) message dropped")
            return

        try:
            if not self._session:
                await self.start()

            payload = {
                "chat_id": self.chat_id,
                "text": message,
                "parse_mode": parse_mode,
            }
            async with self._session.post(
                f"{self.base_url}/sendMessage", json=payload
            ) as resp:
                if resp.status != 200:
                    text = await resp.text()
                    logger.error(f"Telegram send failed ({resp.status}): {text}")
                else:
                    self._sent_timestamps.append(_time.time())
        except Exception as e:
            logger.error(f"Telegram error: {e}")

    # ── Pre-built Messages ──

    async def trade_opened(self, symbol: str, direction: str, contracts: int,
                            entry: float, sl: float, tp: float, strategy: str):
        msg = (
            f"<b>TRADE OPENED</b>\n"
            f"Symbol: {symbol}\n"
            f"Direction: {direction}\n"
            f"Contracts: {contracts}\n"
            f"Entry: {entry:.2f}\n"
            f"SL: {sl:.2f} | TP: {tp:.2f}\n"
            f"Strategy: {strategy}"
        )
        await self.send(msg, critical=True)

    async def trade_closed(self, symbol: str, direction: str, pnl: float,
                            reason: str):
        emoji = "+" if pnl >= 0 else ""
        msg = (
            f"<b>TRADE CLOSED</b>\n"
            f"Symbol: {symbol} ({direction})\n"
            f"PnL: {emoji}${pnl:.2f}\n"
            f"Reason: {reason}"
        )
        await self.send(msg, critical=True)

    async def guardian_alert(self, state: str, reason: str):
        msg = (
            f"<b>GUARDIAN ALERT</b>\n"
            f"State: {state}\n"
            f"Reason: {reason}"
        )
        await self.send(msg, critical=True)

    async def dd_warning(self, level_pct: float, dd_used: float, dd_max: float):
        msg = (
            f"<b>DRAWDOWN WARNING</b>\n"
            f"Level: {level_pct*100:.0f}% of max DD reached\n"
            f"Used: ${dd_used:.2f} / ${dd_max:.2f}"
        )
        await self.send(msg, critical=True)

    async def daily_summary(self, stats: dict):
        msg = (
            f"<b>DAILY SUMMARY</b>\n"
            f"Date: {stats.get('date', 'N/A')}\n"
            f"Trades: {stats.get('trades', 0)}\n"
            f"PnL: ${stats.get('pnl', 0):.2f}\n"
            f"Balance: ${stats.get('balance', 0):.2f}\n"
            f"DD Used: ${stats.get('dd_used', 0):.2f}\n"
            f"Trading Days: {stats.get('trading_days', 0)}/5\n"
            f"Profit Target: ${stats.get('total_pnl', 0):.2f}/$3,000"
        )
        await self.send(msg, critical=True)

    async def heartbeat(self, stats: dict):
        """Periodic 'alive' ping — droppable under rate limit."""
        msg = (
            f"<b>HEARTBEAT</b>\n"
            f"State: {stats.get('state', 'N/A')}\n"
            f"Balance: ${stats.get('balance', 0):.2f}\n"
            f"Daily PnL: ${stats.get('daily_pnl', 0):+.2f}\n"
            f"DD used: ${stats.get('dd_used', 0):.2f}"
        )
        await self.send(msg, critical=False)

    async def bot_started(self):
        await self.send("<b>BOT STARTED</b>\nTradeDay Futures Bot is online.", critical=True)

    async def bot_stopped(self, reason: str = ""):
        await self.send(
            f"<b>BOT STOPPED</b>\nReason: {reason or 'Manual stop'}",
            critical=True,
        )

    async def news_alert(self, event_name: str):
        await self.send(
            f"<b>NEWS ALERT</b>\nFlattening for: {event_name}",
            critical=True,
        )
