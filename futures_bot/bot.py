"""
TradeDay Futures Bot - Main Entry Point
Connects to Tradovate API and runs trading strategies.

Architecture:
  1. Connect to Tradovate
  2. Load strategies (VWAP Mean Reversion + ORB Breakout)
  3. Main loop: fetch bars → check signals → manage positions → enforce rules
  4. Guardian monitors all TradeDay rules continuously
"""

import asyncio
import json
import logging
import os
import signal
import sys
from datetime import datetime, time, timezone, timedelta
from pathlib import Path
from typing import Optional

# Add parent to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from futures_bot.core.tradovate_client import TradovateClient
from futures_bot.core.guardian import Guardian, GuardianState
from futures_bot.core.risk_manager import RiskManager
from futures_bot.core.news_filter import NewsFilter
from futures_bot.core.notifier import TelegramNotifier
from futures_bot.core.status_writer import StatusWriter
from futures_bot.strategies.vwap_mean_reversion import (
    VWAPMeanReversion, Bar as VWAPBar, Signal as VWAPSignal,
)
from futures_bot.strategies.orb_breakout import (
    ORBBreakout, Bar as ORBBar, Signal as ORBSignal,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("logs/bot.log"),
    ]
)
logger = logging.getLogger("bot")

EDT_OFFSET = timedelta(hours=-4)


class FuturesBot:
    """Main trading bot for TradeDay evaluation."""

    def __init__(self, config_path: str = "configs/bot_config.json"):
        self.config = self._load_config(config_path)
        self.running = False

        # Core components
        self.client: Optional[TradovateClient] = None
        self.guardian: Optional[Guardian] = None
        self.risk_mgr: Optional[RiskManager] = None
        self.news_filter: Optional[NewsFilter] = None
        self.notifier: Optional[TelegramNotifier] = None
        self.status_writer: Optional[StatusWriter] = None

        # Strategies
        self.vwap_strategy: Optional[VWAPMeanReversion] = None
        self.orb_strategy: Optional[ORBBreakout] = None
        self.active_strategy: str = "vwap"  # or "orb"

        # Trading state
        self.symbols: list = self.config.get("symbols", ["MESM6"])
        self.timeframe: str = self.config.get("timeframe", "5min")
        self.current_day: str = ""
        self.positions: list = []

    def _load_config(self, path: str) -> dict:
        """Load bot configuration."""
        try:
            with open(path) as f:
                return json.load(f)
        except FileNotFoundError:
            logger.warning(f"Config not found at {path}, using defaults")
            return {}

    async def start(self):
        """Initialize and start the bot."""
        logger.info("=" * 60)
        logger.info("TradeDay Futures Bot Starting")
        logger.info("=" * 60)

        # Initialize Tradovate client (web-style auth, no API keys needed)
        self.client = TradovateClient(
            username=os.environ.get("TRADOVATE_USER", self.config.get("username", "")),
            password=os.environ.get("TRADOVATE_PASS", self.config.get("password", "")),
            live=self.config.get("live", False),
            organization=self.config.get("organization", ""),
        )

        # Initialize modules
        self.guardian = Guardian(self.config.get("guardian", {}))
        self.risk_mgr = RiskManager(self.config.get("risk", {}))
        self.news_filter = NewsFilter()
        self.status_writer = StatusWriter()

        # Telegram
        self.notifier = TelegramNotifier(
            token=os.environ.get("TELEGRAM_TOKEN", ""),
            chat_id=os.environ.get("TELEGRAM_CHAT_ID", ""),
            enabled=self.config.get("telegram_enabled", True),
        )

        # Strategies
        self.vwap_strategy = VWAPMeanReversion(self.config.get("vwap", {}))
        self.orb_strategy = ORBBreakout(self.config.get("orb", {}))

        # Connect
        try:
            await self.client.connect()
            await self.notifier.start()
            await self.notifier.bot_started()
        except Exception as e:
            logger.error(f"Failed to connect: {e}")
            raise

        self.running = True
        logger.info("Bot started successfully")

        # Main loop
        await self._run()

    async def stop(self, reason: str = ""):
        """Stop the bot gracefully."""
        logger.info(f"Stopping bot: {reason}")
        self.running = False

        # Close all positions
        if self.client:
            try:
                await self.client.close_all_positions()
                await self.client.cancel_all_orders()
            except Exception as e:
                logger.error(f"Error closing positions: {e}")

        # Notify
        if self.notifier:
            await self.notifier.bot_stopped(reason)
            await self.notifier.stop()

        # Disconnect
        if self.client:
            await self.client.disconnect()

        logger.info("Bot stopped")

    async def _run(self):
        """Main trading loop."""
        logger.info(f"Trading symbols: {self.symbols}")
        logger.info(f"Timeframe: {self.timeframe}")

        while self.running:
            try:
                now_utc = datetime.now(timezone.utc)
                now_et = now_utc + EDT_OFFSET
                today = now_et.strftime("%Y-%m-%d")

                # New day reset
                if today != self.current_day:
                    await self._handle_new_day(today)

                # Check if we must flatten (end of day)
                if self.risk_mgr.must_flatten():
                    await self._flatten_all("End of day flatten")
                    await asyncio.sleep(60)
                    continue

                # Check news restrictions
                restricted, event_name = self.news_filter.must_flatten_for_event(self.symbols)
                if restricted:
                    await self._flatten_all(f"News event: {event_name}")
                    await self.notifier.news_alert(event_name)
                    await asyncio.sleep(60)
                    continue

                # Check if trading session is active
                in_session, session_msg = self.risk_mgr.is_trading_session()
                if not in_session:
                    await asyncio.sleep(30)
                    continue

                # Check guardian
                if self.guardian.must_close_all():
                    await self._flatten_all(f"Guardian: {self.guardian.reason}")
                    await asyncio.sleep(60)
                    continue

                # Update balance
                try:
                    balance = await self.client.get_account_balance()
                    self.guardian.update_balance(
                        balance["balance"],
                        balance.get("unrealized_pnl", 0),
                    )
                except Exception as e:
                    logger.error(f"Error fetching balance: {e}")

                # Check for trend day at 11:00 ET
                if now_et.hour >= 11:
                    self.vwap_strategy.check_trend_day(now_et.hour)
                    if self.vwap_strategy.is_trend_day() and self.active_strategy == "vwap":
                        self.active_strategy = "orb"
                        logger.info("Switching to ORB strategy (trend day)")

                # Process each symbol
                for symbol in self.symbols:
                    await self._process_symbol(symbol, now_et)

                # Write status
                self.status_writer.write(
                    guardian_status=self.guardian.get_status(),
                    positions=self.positions,
                    extra={"active_strategy": self.active_strategy},
                )

                # Wait for next bar
                sleep_seconds = self._get_sleep_seconds()
                await asyncio.sleep(sleep_seconds)

            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Main loop error: {e}", exc_info=True)
                await asyncio.sleep(10)

    async def _process_symbol(self, symbol: str, now_et: datetime):
        """Process trading signals for a symbol."""
        try:
            # Fetch recent bars
            bars_data = await self.client.get_historical_bars(
                symbol, self.timeframe, count=50
            )
            if not bars_data:
                return

            # Convert to strategy bar format
            bar = self._to_bar(bars_data[-1])

            # Check ORB period (9:30-10:00 ET)
            is_orb_period = time(9, 30) <= now_et.time() < time(10, 0)

            if is_orb_period:
                self.orb_strategy.on_bar(bar, is_orb_period=True)
                return  # Don't trade during ORB building

            # Complete ORB at 10:00
            if now_et.time() >= time(10, 0) and not self.orb_strategy._orb_complete:
                self.orb_strategy.complete_range()

            # Run active strategy
            setup = None
            strategy_name = ""

            if self.active_strategy == "vwap":
                # Feed all bars to VWAP strategy
                for b in bars_data:
                    vbar = self._to_bar(b)
                    setup = self.vwap_strategy.on_bar(vbar)
                strategy_name = "VWAP Mean Reversion"
            else:
                setup = self.orb_strategy.on_bar(bar, is_orb_period=False)
                strategy_name = "ORB Breakout"

            # Execute trade if signal
            if setup and setup.signal.value != 0:
                await self._execute_trade(symbol, setup, strategy_name)

        except Exception as e:
            logger.error(f"Error processing {symbol}: {e}", exc_info=True)

    async def _execute_trade(self, symbol: str, setup, strategy_name: str):
        """Execute a trade from a strategy signal."""
        # Pre-trade checks
        can_trade, reason = self.guardian.can_open_trade(
            num_contracts=1, is_micro=True
        )
        if not can_trade:
            logger.info(f"Trade blocked by guardian: {reason}")
            return

        can_open, reason = self.risk_mgr.can_open_position()
        if not can_open:
            logger.info(f"Trade blocked by risk manager: {reason}")
            return

        # Check news
        restricted, event = self.news_filter.is_restricted(self.symbols)
        if restricted:
            logger.info(f"Trade blocked by news filter: {event}")
            return

        # Determine direction
        signal_val = setup.signal.value
        direction = "Buy" if signal_val == 1 else "Sell"
        is_long = signal_val == 1

        # Calculate position size
        stop_distance = abs(setup.entry_price - setup.stop_loss)
        max_risk = self.guardian.get_max_risk_per_trade()

        # Apply dead zone multiplier
        max_risk *= self.risk_mgr.get_risk_multiplier()

        contracts = self.risk_mgr.calculate_position_size(
            symbol, stop_distance, max_risk
        )

        if contracts <= 0:
            logger.info(f"Position size is 0, skipping trade")
            return

        # Place the trade
        try:
            # Determine TP based on strategy type
            if hasattr(setup, 'take_profit_1'):
                tp = setup.take_profit_1  # VWAP has two TPs
            else:
                tp = setup.take_profit

            result = await self.client.place_market_order(
                symbol=symbol,
                action=direction,
                qty=contracts,
                bracket={
                    "stopLoss": setup.stop_loss,
                    "takeProfit": tp,
                },
            )

            risk_dollars = self.risk_mgr.calculate_stop_risk_dollars(
                symbol, stop_distance, contracts
            )

            logger.info(
                f"TRADE: {direction} {contracts} {symbol} @ {setup.entry_price:.2f} "
                f"SL={setup.stop_loss:.2f} TP={tp:.2f} "
                f"Risk=${risk_dollars:.2f} Strategy={strategy_name}"
            )

            await self.notifier.trade_opened(
                symbol, direction, contracts,
                setup.entry_price, setup.stop_loss, tp, strategy_name
            )

            self.risk_mgr.open_positions += 1
            self.risk_mgr.open_contracts += contracts

        except Exception as e:
            logger.error(f"Failed to execute trade: {e}")

    async def _flatten_all(self, reason: str):
        """Close all positions and cancel all orders."""
        logger.warning(f"FLATTENING ALL: {reason}")
        try:
            await self.client.close_all_positions()
            await self.client.cancel_all_orders()
            self.risk_mgr.open_positions = 0
            self.risk_mgr.open_contracts = 0
        except Exception as e:
            logger.error(f"Error flattening: {e}")

    async def _handle_new_day(self, today: str):
        """Handle the start of a new trading day."""
        logger.info(f"New trading day: {today}")

        # End previous day
        if self.current_day:
            self.guardian.start_new_day(today)

            # Send daily summary
            status = self.guardian.get_status()
            await self.notifier.daily_summary({
                "date": self.current_day,
                "trades": status["daily_trades"],
                "pnl": status["daily_pnl"],
                "balance": status["balance"],
                "dd_used": status["drawdown_used"],
                "trading_days": status["trading_days"],
                "total_pnl": status["total_pnl"],
            })

        self.current_day = today
        self.active_strategy = "vwap"  # Reset to primary strategy

        # Reset strategies
        self.vwap_strategy.reset_day()
        self.orb_strategy.reset_day()

    def _to_bar(self, data: dict):
        """Convert API bar data to strategy Bar format."""
        return VWAPBar(
            timestamp=data.get("timestamp", ""),
            open=data.get("open", 0),
            high=data.get("high", 0),
            low=data.get("low", 0),
            close=data.get("close", 0),
            volume=data.get("volume", 0),
        )

    def _get_sleep_seconds(self) -> int:
        """Calculate sleep time based on timeframe."""
        tf_map = {"1min": 60, "5min": 300, "15min": 900}
        return tf_map.get(self.timeframe, 300)


async def main():
    """Entry point."""
    bot = FuturesBot()

    # Handle shutdown signals
    loop = asyncio.get_event_loop()

    def shutdown_handler():
        asyncio.create_task(bot.stop("Signal received"))

    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, shutdown_handler)
        except NotImplementedError:
            pass  # Windows

    try:
        await bot.start()
    except KeyboardInterrupt:
        await bot.stop("Keyboard interrupt")
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
        await bot.stop(f"Fatal: {e}")


if __name__ == "__main__":
    asyncio.run(main())
