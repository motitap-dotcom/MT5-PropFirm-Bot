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

Path("logs").mkdir(parents=True, exist_ok=True)
Path("status").mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("logs/bot.log"),
    ]
)
logger = logging.getLogger("bot")

try:
    from zoneinfo import ZoneInfo
    ET_TZ = ZoneInfo("America/New_York")
except ImportError:
    from datetime import timezone as _tz
    # Fallback: detect DST by month (approximate)
    ET_TZ = None


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

        # Strategies - one per symbol
        self.vwap_strategies: dict = {}
        self.orb_strategies: dict = {}
        self.active_strategy: dict = {}  # per symbol: "vwap" or "orb"
        self._last_bar_time: dict = {}  # track last processed bar per symbol
        self._processed_fills: set = set()  # track processed fill IDs

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

        # Strategies - separate instance per symbol with per-symbol params
        vwap_base = self.config.get("vwap", {})
        orb_base = self.config.get("orb", {})
        vwap_overrides = self.config.get("vwap_per_symbol", {})
        orb_overrides = self.config.get("orb_per_symbol", {})

        for sym in self.symbols:
            # Get base symbol (strip month code: MESM6 -> MES)
            base = sym.rstrip("0123456789")[:-1] if len(sym) > 3 else sym
            # Merge base config with per-symbol overrides
            vwap_cfg = {**vwap_base, **vwap_overrides.get(base, {})}
            orb_cfg = {**orb_base, **orb_overrides.get(base, {})}
            self.vwap_strategies[sym] = VWAPMeanReversion(vwap_cfg)
            self.orb_strategies[sym] = ORBBreakout(orb_cfg)
            self.active_strategy[sym] = "vwap"
            self._last_bar_time[sym] = ""

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
                if ET_TZ:
                    now_et = now_utc.astimezone(ET_TZ)
                else:
                    # Approximate DST: March-November = EDT (-4), else EST (-5)
                    offset = timedelta(hours=-4) if 3 <= now_utc.month <= 11 else timedelta(hours=-5)
                    now_et = now_utc + offset
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

                # Check for trend day at 11:00 ET (per symbol)
                if now_et.hour >= 11:
                    for sym in self.symbols:
                        vwap = self.vwap_strategies[sym]
                        vwap.check_trend_day(now_et.hour)
                        if vwap.is_trend_day() and self.active_strategy.get(sym) == "vwap":
                            self.active_strategy[sym] = "orb"
                            logger.info(f"Switching {sym} to ORB strategy (trend day)")

                # Sync positions and detect closed trades
                try:
                    positions = await self.client.get_positions()
                    actual_open = sum(1 for p in positions if p.get("netPos", 0) != 0)
                    if actual_open != self.risk_mgr.open_positions:
                        logger.info(f"Position sync: {self.risk_mgr.open_positions} -> {actual_open}")
                        self.risk_mgr.open_positions = actual_open

                    # Detect closed trades via fills
                    fills = await self.client.get_fills()
                    await self._process_fills(fills)
                except Exception as e:
                    logger.error(f"Position sync error: {e}")

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

            # Only process NEW bars (avoid re-feeding old data)
            latest_bar = bars_data[-1]
            bar_time = latest_bar.get("timestamp", "")
            if bar_time == self._last_bar_time.get(symbol, ""):
                return  # Already processed this bar
            self._last_bar_time[symbol] = bar_time

            bar = self._to_bar(latest_bar)

            # Get this symbol's strategy instances
            vwap = self.vwap_strategies[symbol]
            orb = self.orb_strategies[symbol]

            # Check ORB period (9:30-10:00 ET)
            is_orb_period = time(9, 30) <= now_et.time() < time(10, 0)

            if is_orb_period:
                orb.on_bar(bar, is_orb_period=True)
                return  # Don't trade during ORB building

            # Complete ORB at 10:00
            if now_et.time() >= time(10, 0) and not orb._orb_complete:
                orb.complete_range()

            # Run active strategy for THIS symbol
            setup = None
            strategy_name = ""
            sym_strategy = self.active_strategy.get(symbol, "vwap")

            if sym_strategy == "vwap":
                # Feed only the latest bar
                setup = vwap.on_bar(bar)
                strategy_name = "VWAP Mean Reversion"
            else:
                setup = orb.on_bar(bar, is_orb_period=False)
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

        # Determine TP based on strategy type
        if hasattr(setup, 'take_profit_1'):
            tp = setup.take_profit_1  # VWAP has two TPs
        else:
            tp = setup.take_profit

        sl = setup.stop_loss
        risk_dollars = self.risk_mgr.calculate_stop_risk_dollars(
            symbol, stop_distance, contracts
        )

        # SAFETY: Verify SL and TP are set and valid
        if sl == 0 or tp == 0:
            logger.error(f"BLOCKED: SL or TP is zero! SL={sl} TP={tp}")
            return
        if direction == "Buy" and sl >= setup.entry_price:
            logger.error(f"BLOCKED: SL ({sl}) >= entry ({setup.entry_price}) for LONG")
            return
        if direction == "Sell" and sl <= setup.entry_price:
            logger.error(f"BLOCKED: SL ({sl}) <= entry ({setup.entry_price}) for SHORT")
            return

        # Place the trade with bracket (SL + TP)
        try:
            result = await self.client.place_market_order(
                symbol=symbol,
                action=direction,
                qty=contracts,
                bracket={
                    "stopLoss": sl,
                    "takeProfit": tp,
                },
            )

            order_id = result.get("orderId")

            logger.info(
                f"TRADE: {direction} {contracts} {symbol} @ {setup.entry_price:.2f} "
                f"SL={sl:.2f} TP={tp:.2f} "
                f"Risk=${risk_dollars:.2f} Strategy={strategy_name}"
            )

            # DOUBLE CHECK: Verify SL/TP orders exist after 2 seconds
            await asyncio.sleep(2)
            await self._verify_bracket_orders(symbol, direction, contracts, sl, tp)

            await self.notifier.trade_opened(
                symbol, direction, contracts,
                setup.entry_price, sl, tp, strategy_name
            )

            self.risk_mgr.open_positions += 1
            self.risk_mgr.open_contracts += contracts

        except Exception as e:
            logger.error(f"Failed to execute trade: {e}")
            # EMERGENCY: If trade was placed but bracket failed, close immediately
            try:
                positions = await self.client.get_positions()
                for pos in positions:
                    if pos.get("netPos", 0) != 0:
                        contract = await self.client.get_contract_by_id(pos["contractId"])
                        if contract.get("name", "").startswith(symbol.rstrip("0123456789")):
                            logger.warning(f"EMERGENCY CLOSE: Trade without SL/TP for {symbol}")
                            await self.client.close_position(symbol)
                            await self.notifier.guardian_alert(
                                "EMERGENCY", f"Closed {symbol} - bracket orders failed"
                            )
            except Exception as e2:
                logger.error(f"Emergency close failed: {e2}")

    async def _process_fills(self, fills: list):
        """Process fills to detect closed trades and update PnL."""
        for fill in fills:
            fill_id = fill.get("id", 0)
            if fill_id in self._processed_fills:
                continue
            self._processed_fills.add(fill_id)

            action = fill.get("action", "")
            qty = fill.get("qty", 0)
            price = fill.get("price", 0)
            pnl = fill.get("pnl", 0)

            if pnl != 0:
                # This is a closing fill (has PnL)
                self.guardian.record_trade(pnl)
                is_win = pnl > 0

                # Record result in strategies
                for sym in self.symbols:
                    self.vwap_strategies[sym].record_trade_result(is_win)

                contract_id = fill.get("contractId", "")
                logger.info(f"FILL: {action} {qty} @ {price:.2f} PnL=${pnl:.2f}")

                await self.notifier.trade_closed(
                    str(contract_id), action, pnl, "SL/TP hit"
                )

    async def _verify_bracket_orders(self, symbol: str, direction: str,
                                       qty: int, sl: float, tp: float):
        """
        DOUBLE CHECK: Verify that SL and TP orders exist for a position.
        If missing, place them immediately. If that fails too, close the position.
        """
        try:
            orders = await self.client.get_open_orders()
            exit_action = "Sell" if direction == "Buy" else "Buy"

            has_sl = False
            has_tp = False
            for order in orders:
                if order.get("action") == exit_action:
                    if order.get("orderType") == "Stop":
                        has_sl = True
                    elif order.get("orderType") == "Limit":
                        has_tp = True

            if not has_sl:
                logger.warning(f"NO STOP LOSS found for {symbol}! Placing emergency SL...")
                try:
                    await self.client.place_stop_order(symbol, exit_action, qty, sl)
                    logger.info(f"Emergency SL placed at {sl}")
                except Exception as e:
                    logger.error(f"FAILED to place emergency SL: {e}")
                    logger.warning(f"CLOSING POSITION {symbol} - cannot set SL!")
                    await self.client.close_position(symbol)
                    await self.notifier.guardian_alert(
                        "EMERGENCY", f"Closed {symbol} - could not set stop loss"
                    )
                    return

            if not has_tp:
                logger.warning(f"NO TAKE PROFIT found for {symbol}! Placing emergency TP...")
                try:
                    await self.client.place_limit_order(symbol, exit_action, qty, tp)
                    logger.info(f"Emergency TP placed at {tp}")
                except Exception as e:
                    logger.warning(f"Could not place TP for {symbol}: {e} (SL exists, continuing)")

            if has_sl and has_tp:
                logger.info(f"Bracket verified: SL and TP confirmed for {symbol}")

        except Exception as e:
            logger.error(f"Bracket verification error: {e}")

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

        # Reset strategies for all symbols
        for sym in self.symbols:
            self.vwap_strategies[sym].reset_day()
            self.orb_strategies[sym].reset_day()
            self.active_strategy[sym] = "vwap"
            self._last_bar_time[sym] = ""

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
    """Entry point with retry logic for connection failures."""
    MAX_RETRIES = 5
    RETRY_DELAYS = [30, 60, 120, 300, 600]  # 30s, 1m, 2m, 5m, 10m

    # Handle shutdown signals
    loop = asyncio.get_event_loop()
    shutdown_requested = False

    def shutdown_handler():
        nonlocal shutdown_requested
        shutdown_requested = True

    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, shutdown_handler)
        except NotImplementedError:
            pass  # Windows

    for attempt in range(MAX_RETRIES):
        if shutdown_requested:
            break

        bot = FuturesBot()

        # Wire up shutdown handler to current bot instance
        def make_stop_handler(b):
            def handler():
                nonlocal shutdown_requested
                shutdown_requested = True
                asyncio.create_task(b.stop("Signal received"))
            return handler

        for sig in (signal.SIGINT, signal.SIGTERM):
            try:
                loop.add_signal_handler(sig, make_stop_handler(bot))
            except NotImplementedError:
                pass

        try:
            await bot.start()
            break  # Clean exit
        except KeyboardInterrupt:
            await bot.stop("Keyboard interrupt")
            break
        except Exception as e:
            logger.error(f"Fatal error (attempt {attempt + 1}/{MAX_RETRIES}): {e}", exc_info=True)
            await bot.stop(f"Fatal: {e}")

            if attempt < MAX_RETRIES - 1 and not shutdown_requested:
                delay = RETRY_DELAYS[attempt]
                logger.info(f"Retrying in {delay}s...")
                await asyncio.sleep(delay)
            else:
                logger.error("Max retries reached. Bot shutting down permanently.")


if __name__ == "__main__":
    asyncio.run(main())
