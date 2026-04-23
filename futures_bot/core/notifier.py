"""
Telegram Notification Module
Sends alerts for trades, guardian state changes, and daily summaries.
"""

import logging
import asyncio
from typing import Optional
import aiohttp

logger = logging.getLogger("notifier")


class TelegramNotifier:
    """Sends notifications via Telegram Bot API."""

    def __init__(self, token: str, chat_id: str, enabled: bool = True):
        self.token = token
        self.chat_id = chat_id
        self.enabled = enabled
        self.base_url = f"https://api.telegram.org/bot{token}"
        self._session: Optional[aiohttp.ClientSession] = None

    async def start(self):
        self._session = aiohttp.ClientSession()

    async def stop(self):
        if self._session:
            await self._session.close()

    async def send(self, message: str, parse_mode: str = "HTML"):
        """Send a message to Telegram."""
        if not self.enabled or not self.token or not self.chat_id:
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
        await self.send(msg)

    async def trade_closed(self, symbol: str, direction: str, pnl: float,
                            reason: str):
        emoji = "+" if pnl >= 0 else ""
        msg = (
            f"<b>TRADE CLOSED</b>\n"
            f"Symbol: {symbol} ({direction})\n"
            f"PnL: {emoji}${pnl:.2f}\n"
            f"Reason: {reason}"
        )
        await self.send(msg)

    async def guardian_alert(self, state: str, reason: str):
        msg = (
            f"<b>GUARDIAN ALERT</b>\n"
            f"State: {state}\n"
            f"Reason: {reason}"
        )
        await self.send(msg)

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
        await self.send(msg)

    async def bot_started(self):
        await self.send("<b>BOT STARTED</b>\nTradeDay Futures Bot is online.")

    async def bot_stopped(self, reason: str = ""):
        await self.send(f"<b>BOT STOPPED</b>\nReason: {reason or 'Manual stop'}")

    async def news_alert(self, event_name: str):
        await self.send(f"<b>NEWS ALERT</b>\nFlattening for: {event_name}")

    async def data_stale_alert(self, symbols: list):
        """Alert when market data has been empty for multiple cycles."""
        await self.send(
            f"<b>⚠️ NO MARKET DATA</b>\n"
            f"Bot is running but /md/getChart returned 0 bars for "
            f"{len(symbols)} cycles on: {', '.join(symbols)}\n"
            f"Check MD WebSocket connection."
        )
