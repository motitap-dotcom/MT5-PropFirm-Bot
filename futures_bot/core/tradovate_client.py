"""
Tradovate API Client
Handles authentication, order management, and market data via REST + WebSocket.
"""

import asyncio
import json
import time
import logging
from datetime import datetime, timezone
from typing import Optional, Dict, Any, List, Callable

import aiohttp
import websockets

logger = logging.getLogger("tradovate_client")


class TradovateClient:
    """Client for Tradovate REST and WebSocket APIs."""

    # API base URLs
    DEMO_URL = "https://demo.tradovateapi.com/v1"
    LIVE_URL = "https://live.tradovateapi.com/v1"
    MD_WS_URL = "wss://md.tradovateapi.com/v1/websocket"
    DEMO_WS_URL = "wss://demo.tradovateapi.com/v1/websocket"
    LIVE_WS_URL = "wss://live.tradovateapi.com/v1/websocket"

    def __init__(self, username: str, password: str, app_id: str = "",
                 app_version: str = "1.0", cid: int = 0, sec: str = "",
                 live: bool = False):
        self.username = username
        self.password = password
        self.app_id = app_id
        self.app_version = app_version
        self.cid = cid
        self.sec = sec
        self.live = live

        self.base_url = self.LIVE_URL if live else self.DEMO_URL
        self.ws_url = self.LIVE_WS_URL if live else self.DEMO_WS_URL

        self.access_token: Optional[str] = None
        self.token_expiry: float = 0
        self.session: Optional[aiohttp.ClientSession] = None

        # WebSocket connections
        self._md_ws = None  # Market data
        self._order_ws = None  # Order updates
        self._callbacks: Dict[str, List[Callable]] = {}

        # Account info
        self.account_id: Optional[int] = None
        self.account_spec: Optional[str] = None

    async def connect(self):
        """Initialize session and authenticate."""
        self.session = aiohttp.ClientSession()
        await self._authenticate()
        await self._get_account_info()
        logger.info(f"Connected to Tradovate ({'LIVE' if self.live else 'DEMO'}) "
                     f"as {self.username}, account_id={self.account_id}")

    async def disconnect(self):
        """Clean up connections."""
        if self._md_ws:
            await self._md_ws.close()
        if self._order_ws:
            await self._order_ws.close()
        if self.session:
            await self.session.close()
        logger.info("Disconnected from Tradovate")

    async def _authenticate(self):
        """Get access token via REST API."""
        payload = {
            "name": self.username,
            "password": self.password,
            "appId": self.app_id,
            "appVersion": self.app_version,
            "cid": self.cid,
            "sec": self.sec,
        }
        async with self.session.post(f"{self.base_url}/auth/accesstokenrequest",
                                      json=payload) as resp:
            if resp.status != 200:
                text = await resp.text()
                raise ConnectionError(f"Auth failed ({resp.status}): {text}")
            data = await resp.json()

        self.access_token = data.get("accessToken")
        expiry_str = data.get("expirationTime", "")
        if expiry_str:
            # Parse ISO datetime
            try:
                dt = datetime.fromisoformat(expiry_str.replace("Z", "+00:00"))
                self.token_expiry = dt.timestamp()
            except (ValueError, TypeError):
                self.token_expiry = time.time() + 3600

        if not self.access_token:
            raise ConnectionError(f"No access token received: {data}")

        logger.info("Authenticated successfully")

    async def _ensure_token(self):
        """Refresh token if close to expiry."""
        if time.time() > self.token_expiry - 300:  # 5 min buffer
            await self._authenticate()

    def _headers(self) -> Dict[str, str]:
        return {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
        }

    async def _get(self, endpoint: str) -> Any:
        """GET request to REST API."""
        await self._ensure_token()
        async with self.session.get(f"{self.base_url}{endpoint}",
                                     headers=self._headers()) as resp:
            if resp.status != 200:
                text = await resp.text()
                raise Exception(f"GET {endpoint} failed ({resp.status}): {text}")
            return await resp.json()

    async def _post(self, endpoint: str, data: Dict = None) -> Any:
        """POST request to REST API."""
        await self._ensure_token()
        async with self.session.post(f"{self.base_url}{endpoint}",
                                      headers=self._headers(),
                                      json=data or {}) as resp:
            if resp.status != 200:
                text = await resp.text()
                raise Exception(f"POST {endpoint} failed ({resp.status}): {text}")
            return await resp.json()

    # ── Account Info ──

    async def _get_account_info(self):
        """Fetch account ID and spec."""
        accounts = await self._get("/account/list")
        if not accounts:
            raise Exception("No accounts found")
        # Use first account
        acc = accounts[0]
        self.account_id = acc["id"]
        self.account_spec = acc.get("name", str(self.account_id))
        logger.info(f"Account: {self.account_spec} (id={self.account_id})")

    async def get_account_balance(self) -> Dict[str, float]:
        """Get current account balance and equity."""
        cash = await self._get(f"/cashBalance/getCashBalanceSnapshot?accountId={self.account_id}")
        return {
            "balance": cash.get("totalCashValue", 0),
            "realized_pnl": cash.get("realizedPnl", 0),
            "unrealized_pnl": cash.get("openPnl", 0),
        }

    # ── Contract Lookup ──

    async def find_contract(self, symbol: str) -> Dict:
        """Find a contract by symbol name (e.g., 'MESM5', 'MNQM5')."""
        result = await self._get(f"/contract/find?name={symbol}")
        return result

    async def get_contract_by_id(self, contract_id: int) -> Dict:
        """Get contract details by ID."""
        return await self._get(f"/contract/item?id={contract_id}")

    # ── Order Management ──

    async def place_market_order(self, symbol: str, action: str, qty: int,
                                  bracket: Optional[Dict] = None) -> Dict:
        """
        Place a market order.
        action: 'Buy' or 'Sell'
        bracket: optional {'stopLoss': float, 'takeProfit': float}
        """
        contract = await self.find_contract(symbol)
        contract_id = contract["id"]

        order_data = {
            "accountSpec": self.account_spec,
            "accountId": self.account_id,
            "action": action,
            "symbol": symbol,
            "orderQty": qty,
            "orderType": "Market",
            "isAutomated": True,
        }

        result = await self._post("/order/placeorder", order_data)
        order_id = result.get("orderId")
        logger.info(f"Market order placed: {action} {qty} {symbol}, orderId={order_id}")

        # Place bracket orders if specified
        if bracket and order_id:
            await self._place_bracket(order_id, contract_id, action, qty, bracket)

        return result

    async def place_limit_order(self, symbol: str, action: str, qty: int,
                                 price: float) -> Dict:
        """Place a limit order."""
        order_data = {
            "accountSpec": self.account_spec,
            "accountId": self.account_id,
            "action": action,
            "symbol": symbol,
            "orderQty": qty,
            "orderType": "Limit",
            "price": price,
            "isAutomated": True,
        }
        result = await self._post("/order/placeorder", order_data)
        logger.info(f"Limit order: {action} {qty} {symbol} @ {price}")
        return result

    async def place_stop_order(self, symbol: str, action: str, qty: int,
                                stop_price: float) -> Dict:
        """Place a stop order."""
        order_data = {
            "accountSpec": self.account_spec,
            "accountId": self.account_id,
            "action": action,
            "symbol": symbol,
            "orderQty": qty,
            "orderType": "Stop",
            "stopPrice": stop_price,
            "isAutomated": True,
        }
        result = await self._post("/order/placeorder", order_data)
        logger.info(f"Stop order: {action} {qty} {symbol} @ stop={stop_price}")
        return result

    async def _place_bracket(self, parent_order_id: int, contract_id: int,
                              action: str, qty: int, bracket: Dict):
        """Place stop loss and take profit around a filled order."""
        exit_action = "Sell" if action == "Buy" else "Buy"

        if "stopLoss" in bracket:
            await self.place_stop_order(
                symbol="",  # Will be resolved from parent
                action=exit_action,
                qty=qty,
                stop_price=bracket["stopLoss"],
            )

        if "takeProfit" in bracket:
            await self.place_limit_order(
                symbol="",
                action=exit_action,
                qty=qty,
                price=bracket["takeProfit"],
            )

    async def cancel_order(self, order_id: int) -> Dict:
        """Cancel an open order."""
        result = await self._post("/order/cancelorder", {"orderId": order_id})
        logger.info(f"Cancelled order {order_id}")
        return result

    async def cancel_all_orders(self) -> None:
        """Cancel all open orders for this account."""
        orders = await self.get_open_orders()
        for order in orders:
            try:
                await self.cancel_order(order["id"])
            except Exception as e:
                logger.error(f"Failed to cancel order {order['id']}: {e}")

    async def close_position(self, symbol: str) -> Optional[Dict]:
        """Close an open position by placing an opposing market order."""
        positions = await self.get_positions()
        for pos in positions:
            if pos.get("contractId"):
                contract = await self.get_contract_by_id(pos["contractId"])
                if contract.get("name", "").startswith(symbol):
                    net_pos = pos.get("netPos", 0)
                    if net_pos == 0:
                        continue
                    action = "Sell" if net_pos > 0 else "Buy"
                    qty = abs(net_pos)
                    return await self.place_market_order(symbol, action, qty)
        return None

    async def close_all_positions(self) -> None:
        """Close all open positions."""
        positions = await self.get_positions()
        for pos in positions:
            net_pos = pos.get("netPos", 0)
            if net_pos != 0:
                contract = await self.get_contract_by_id(pos["contractId"])
                symbol = contract.get("name", "")
                action = "Sell" if net_pos > 0 else "Buy"
                try:
                    await self.place_market_order(symbol, action, abs(net_pos))
                except Exception as e:
                    logger.error(f"Failed to close position {symbol}: {e}")

    # ── Position & Order Queries ──

    async def get_positions(self) -> List[Dict]:
        """Get all open positions."""
        return await self._get(f"/position/list")

    async def get_open_orders(self) -> List[Dict]:
        """Get all open orders."""
        return await self._get(f"/order/list")

    async def get_fills(self) -> List[Dict]:
        """Get today's fills."""
        return await self._get(f"/fill/list")

    # ── Market Data (WebSocket) ──

    async def subscribe_market_data(self, symbol: str, callback: Callable):
        """Subscribe to real-time quotes for a symbol."""
        if not self._md_ws:
            await self._connect_md_websocket()

        self._callbacks.setdefault(symbol, []).append(callback)

        # Send subscription message
        sub_msg = f"md/subscribeQuote\n2\n\n{json.dumps({'symbol': symbol})}"
        await self._md_ws.send(sub_msg)
        logger.info(f"Subscribed to market data: {symbol}")

    async def _connect_md_websocket(self):
        """Connect to market data WebSocket."""
        self._md_ws = await websockets.connect(self.MD_WS_URL)
        # Authenticate
        auth_msg = f"authorize\n1\n\n{self.access_token}"
        await self._md_ws.send(auth_msg)
        response = await self._md_ws.recv()
        logger.info(f"MD WebSocket connected: {response[:100]}")

        # Start listening in background
        asyncio.create_task(self._listen_md())

    async def _listen_md(self):
        """Listen for market data messages."""
        try:
            async for message in self._md_ws:
                try:
                    self._process_md_message(message)
                except Exception as e:
                    logger.error(f"Error processing MD message: {e}")
        except websockets.ConnectionClosed:
            logger.warning("MD WebSocket disconnected, reconnecting...")
            await asyncio.sleep(2)
            await self._connect_md_websocket()

    def _process_md_message(self, message: str):
        """Parse and dispatch market data messages."""
        # Tradovate WS messages have format: event\nid\n\njson_data
        parts = message.split("\n", 3)
        if len(parts) < 4:
            return

        event_type = parts[0]
        try:
            data = json.loads(parts[3]) if parts[3] else {}
        except json.JSONDecodeError:
            return

        if event_type in ("md/quote", "md/subscribeQuote"):
            symbol = data.get("contractSymbol", "")
            for cb in self._callbacks.get(symbol, []):
                try:
                    cb(data)
                except Exception as e:
                    logger.error(f"Callback error for {symbol}: {e}")

    # ── Historical Data ──

    async def get_historical_bars(self, symbol: str, timeframe: str = "5min",
                                   count: int = 100) -> List[Dict]:
        """
        Get historical OHLCV bars.
        timeframe: '1min', '5min', '15min', '30min', '1hour', '1day'
        """
        # Map timeframe to Tradovate elementSize/elementSizeUnit
        tf_map = {
            "1min": (1, "Minute"),
            "5min": (5, "Minute"),
            "15min": (15, "Minute"),
            "30min": (30, "Minute"),
            "1hour": (1, "Hour"),
            "1day": (1, "Day"),
        }
        size, unit = tf_map.get(timeframe, (5, "Minute"))

        contract = await self.find_contract(symbol)
        contract_id = contract["id"]

        # Use MD endpoint for historical data
        result = await self._post("/md/getChart", {
            "symbol": symbol,
            "chartDescription": {
                "underlyingType": "MinuteBar",
                "elementSize": size,
                "elementSizeUnit": unit,
                "withHistogram": False,
            },
            "timeRange": {
                "closestTimestamp": datetime.now(timezone.utc).isoformat(),
                "asFarAsTimestamp": "",
            },
        })
        return result.get("bars", [])
