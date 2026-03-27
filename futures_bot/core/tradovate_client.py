"""
Tradovate API Client
Handles authentication, order management, and market data via REST + WebSocket.

Auth method: Web-style authentication (no API keys needed).
Uses appId="tradovate_trader(web)", cid=8, sec="" to mimic the web trader.
First login from new IP requires solving CAPTCHA once, then token auto-renews.
"""

import asyncio
import json
import time
import uuid
import logging
from datetime import datetime, timezone
from typing import Optional, Dict, Any, List, Callable
from pathlib import Path

import aiohttp
import websockets

logger = logging.getLogger("tradovate_client")

# Token file path for persistence across restarts
TOKEN_FILE = Path("configs/.tradovate_token.json")


class TradovateClient:
    """Client for Tradovate REST and WebSocket APIs."""

    # API base URLs
    DEMO_URL = "https://demo.tradovateapi.com/v1"
    LIVE_URL = "https://live.tradovateapi.com/v1"

    # WebSocket URLs
    DEMO_WS_URL = "wss://demo.tradovateapi.com/v1/websocket"
    LIVE_WS_URL = "wss://live.tradovateapi.com/v1/websocket"
    DEMO_MD_WS_URL = "wss://md-demo.tradovateapi.com/v1/websocket"
    LIVE_MD_WS_URL = "wss://md.tradovateapi.com/v1/websocket"

    # Web-style auth constants (no API key subscription needed)
    WEB_APP_ID = "tradovate_trader(web)"
    WEB_APP_VERSION = "3.260220.0"
    WEB_CID = 8
    WEB_SEC = ""

    def __init__(self, username: str, password: str, live: bool = False,
                 organization: str = ""):
        self.username = username
        self.password = password
        self.live = live
        self.organization = organization  # Empty for TradeDay
        self.device_id = str(uuid.uuid4())

        self.base_url = self.LIVE_URL if live else self.DEMO_URL
        self.ws_url = self.LIVE_WS_URL if live else self.DEMO_WS_URL
        self.md_ws_url = self.LIVE_MD_WS_URL if live else self.DEMO_MD_WS_URL

        self.access_token: Optional[str] = None
        self.md_access_token: Optional[str] = None
        self.token_expiry: float = 0
        self.session: Optional[aiohttp.ClientSession] = None

        # WebSocket connections
        self._md_ws = None  # Market data
        self._trading_ws = None  # Trading/order updates
        self._callbacks: Dict[str, List[Callable]] = {}
        self._ws_request_id: int = 10
        self._heartbeat_task: Optional[asyncio.Task] = None

        # Account info
        self.account_id: Optional[int] = None
        self.account_spec: Optional[str] = None

    async def connect(self):
        """Initialize session and authenticate."""
        self.session = aiohttp.ClientSession()

        # Try to load saved token first
        if self._load_saved_token():
            logger.info("Loaded saved token, verifying...")
            try:
                await self._get_account_info()
                logger.info("Saved token is valid")
            except Exception:
                logger.info("Saved token expired, trying to renew...")
                try:
                    await self._renew_token()
                    await self._get_account_info()
                    logger.info("Token renewed successfully on startup")
                except Exception:
                    logger.info("Renewal failed, full re-authentication...")
                    await self._authenticate()
                    await self._get_account_info()
        else:
            await self._authenticate()
            await self._get_account_info()

        logger.info(f"Connected to Tradovate ({'LIVE' if self.live else 'DEMO'}) "
                     f"as {self.username}, account_id={self.account_id}")

    async def disconnect(self):
        """Clean up connections."""
        if self._heartbeat_task:
            self._heartbeat_task.cancel()
        if self._md_ws:
            await self._md_ws.close()
        if self._trading_ws:
            await self._trading_ws.close()
        if self.session:
            await self.session.close()
        logger.info("Disconnected from Tradovate")

    # ── Authentication ──

    async def _authenticate(self):
        """
        Authenticate using web-style auth.
        No API keys needed - uses same method as Tradovate web trader.
        """
        # First try: check if we have a pre-set access token (from CAPTCHA flow)
        import os
        preset_token = os.environ.get("TRADOVATE_ACCESS_TOKEN", "").strip()
        if preset_token:
            self.access_token = preset_token
            self.token_expiry = time.time() + 86400  # Assume 24h
            logger.info("Using pre-set access token from environment")
            # Verify token works before saving
            try:
                self._save_token()
                await self._get_account_info()
                logger.info("Pre-set token is valid")
                return
            except Exception:
                logger.warning("Pre-set token from environment is expired/invalid, falling back to user/password auth...")
                self.access_token = None

        payload = {
            "name": self.username,
            "password": self.password,
            "appId": self.WEB_APP_ID,
            "appVersion": self.WEB_APP_VERSION,
            "deviceId": self.device_id,
            "cid": self.WEB_CID,
            "sec": self.WEB_SEC,
            "organization": self.organization,
        }

        try:
            async with self.session.post(
                f"{self.base_url}/auth/accesstokenrequest",
                json=payload
            ) as resp:
                if resp.content_type == "application/json":
                    data = await resp.json()
                else:
                    text = await resp.text()
                    raise ConnectionError(
                        f"Auth returned non-JSON ({resp.status}): {text[:200]}"
                    )
        except ConnectionError:
            raise
        except Exception as e:
            raise ConnectionError(f"Auth request failed: {e}")

        # Handle different response scenarios
        if "accessToken" in data:
            # Success - got full token set
            self.access_token = data["accessToken"]
            self.md_access_token = data.get("mdAccessToken", self.access_token)
            self._parse_expiry(data.get("expirationTime", ""))
            self._save_token()
            logger.info("Authenticated successfully (direct)")
            return

        if "p-ticket" in data:
            # CAPTCHA or wait required
            p_ticket = data["p-ticket"]
            p_time = data.get("p-time", 15)
            p_captcha = data.get("p-captcha", False)

            if p_captcha:
                # CAPTCHA required - need manual intervention
                logger.error(
                    "CAPTCHA required for first login!\n"
                    "Run: python3 get_token.py\n"
                    "Or set TRADOVATE_ACCESS_TOKEN in .env after solving CAPTCHA in browser."
                )
                raise ConnectionError(
                    "CAPTCHA required. Run get_token.py on a machine with a browser, "
                    "then set TRADOVATE_ACCESS_TOKEN in .env"
                )
            else:
                # Wait and retry (no CAPTCHA)
                logger.info(f"Waiting {p_time}s before retry (p-ticket received)...")
                await asyncio.sleep(p_time)

                payload["p-ticket"] = p_ticket
                async with self.session.post(
                    f"{self.base_url}/auth/accesstokenrequest",
                    json=payload
                ) as resp:
                    data = await resp.json()

                if "accessToken" in data:
                    self.access_token = data["accessToken"]
                    self.md_access_token = data.get("mdAccessToken", self.access_token)
                    self._parse_expiry(data.get("expirationTime", ""))
                    self._save_token()
                    logger.info("Authenticated successfully (after wait)")
                    return

        # Auth failed
        error = data.get("errorText", str(data))
        raise ConnectionError(f"Authentication failed: {error}")

    async def _renew_token(self):
        """Renew access token (no re-auth needed, no CAPTCHA)."""
        try:
            async with self.session.post(
                f"{self.base_url}/auth/renewaccesstoken",
                headers=self._headers()
            ) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    self.access_token = data.get("accessToken", self.access_token)
                    self.md_access_token = data.get("mdAccessToken", self.access_token)
                    self._parse_expiry(data.get("expirationTime", ""))
                    self._save_token()
                    logger.info("Token renewed successfully")
                else:
                    logger.warning(f"Token renewal failed ({resp.status}), re-authenticating...")
                    await self._authenticate()
        except Exception as e:
            logger.error(f"Token renewal error: {e}")
            await self._authenticate()

    async def _ensure_token(self):
        """Refresh token if close to expiry (1 hour buffer)."""
        if time.time() > self.token_expiry - 3600:
            logger.info("Token expiring soon, renewing...")
            await self._renew_token()

    def _parse_expiry(self, expiry_str: str):
        """Parse token expiration time."""
        if expiry_str:
            try:
                dt = datetime.fromisoformat(expiry_str.replace("Z", "+00:00"))
                self.token_expiry = dt.timestamp()
            except (ValueError, TypeError):
                self.token_expiry = time.time() + 86400  # 24h default
        else:
            self.token_expiry = time.time() + 86400

    def _save_token(self):
        """Save token to file for persistence across restarts."""
        try:
            TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
            data = {
                "access_token": self.access_token,
                "md_access_token": self.md_access_token,
                "expiry": self.token_expiry,
                "saved_at": datetime.now(timezone.utc).isoformat(),
            }
            TOKEN_FILE.write_text(json.dumps(data))
        except Exception as e:
            logger.warning(f"Could not save token: {e}")

    def _load_saved_token(self) -> bool:
        """Load token from file. Returns True if valid token loaded."""
        try:
            if not TOKEN_FILE.exists():
                return False
            data = json.loads(TOKEN_FILE.read_text())
            expiry = data.get("expiry", 0)
            if time.time() < expiry - 300:  # Still valid with 5 min buffer
                self.access_token = data["access_token"]
                self.md_access_token = data.get("md_access_token")
                self.token_expiry = expiry
                return True
        except Exception:
            pass
        return False

    def _headers(self) -> Dict[str, str]:
        return {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
        }

    # ── REST Helpers ──

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
        acc = accounts[0]
        self.account_id = acc["id"]
        self.account_spec = acc.get("name", str(self.account_id))
        logger.info(f"Account: {self.account_spec} (id={self.account_id})")

    async def get_account_balance(self) -> Dict[str, float]:
        """Get current account balance and equity."""
        cash = await self._post(
            "/cashBalance/getcashbalancesnapshot",
            {"accountId": self.account_id}
        )
        return {
            "balance": cash.get("totalCashValue", 0),
            "realized_pnl": cash.get("realizedPnl", 0),
            "unrealized_pnl": cash.get("openPnl", 0),
        }

    # ── Contract Lookup ──

    async def find_contract(self, symbol: str) -> Dict:
        """Find a contract by symbol name (e.g., 'MESM6', 'MNQM6')."""
        return await self._get(f"/contract/find?name={symbol}")

    async def suggest_contract(self, base_symbol: str) -> Dict:
        """Get front-month contract for a base symbol (e.g., 'MES' -> 'MESM6')."""
        return await self._get(f"/contract/suggest?t={base_symbol}&l=1")

    async def get_contract_by_id(self, contract_id: int) -> Dict:
        """Get contract details by ID."""
        return await self._get(f"/contract/item?id={contract_id}")

    # ── Order Management ──

    async def place_market_order(self, symbol: str, action: str, qty: int,
                                  bracket: Optional[Dict] = None) -> Dict:
        """
        Place a market order with optional SL/TP bracket.
        action: 'Buy' or 'Sell'
        bracket: optional {'stopLoss': float, 'takeProfit': float}
        """
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

        # Place separate SL and TP orders (NOT OSO which creates another market order)
        if bracket and order_id:
            exit_action = "Sell" if action == "Buy" else "Buy"
            if "stopLoss" in bracket:
                await self.place_stop_order(symbol, exit_action, qty, bracket["stopLoss"])
            if "takeProfit" in bracket:
                await self.place_limit_order(symbol, exit_action, qty, bracket["takeProfit"])

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

    async def _place_oso_bracket(self, symbol: str, action: str, qty: int,
                                  bracket: Dict):
        """Place OSO bracket order (SL + TP linked to entry)."""
        exit_action = "Sell" if action == "Buy" else "Buy"
        other_orders = []

        if "stopLoss" in bracket:
            other_orders.append({
                "action": exit_action,
                "symbol": symbol,
                "orderQty": qty,
                "orderType": "Stop",
                "stopPrice": bracket["stopLoss"],
                "isAutomated": True,
            })

        if "takeProfit" in bracket:
            other_orders.append({
                "action": exit_action,
                "symbol": symbol,
                "orderQty": qty,
                "orderType": "Limit",
                "price": bracket["takeProfit"],
                "isAutomated": True,
            })

        if other_orders:
            oso_data = {
                "accountSpec": self.account_spec,
                "accountId": self.account_id,
                "action": action,
                "symbol": symbol,
                "orderQty": qty,
                "orderType": "Market",
                "isAutomated": True,
                "bracket1": other_orders[0] if len(other_orders) > 0 else None,
                "bracket2": other_orders[1] if len(other_orders) > 1 else None,
            }
            try:
                result = await self._post("/order/placeOSO", oso_data)
                logger.info(f"OSO bracket placed for {symbol}")
                return result
            except Exception as e:
                logger.warning(f"OSO failed, placing separate orders: {e}")
                for order in other_orders:
                    order["accountSpec"] = self.account_spec
                    order["accountId"] = self.account_id
                    await self._post("/order/placeorder", order)

    async def cancel_order(self, order_id: int) -> Dict:
        """Cancel an open order."""
        result = await self._post("/order/cancelorder", {"orderId": order_id})
        logger.info(f"Cancelled order {order_id}")
        return result

    async def modify_order(self, order_id: int, price: float = None,
                            stop_price: float = None, qty: int = None) -> Dict:
        """Modify an existing order."""
        mod_data = {"orderId": order_id}
        if price is not None:
            mod_data["price"] = price
        if stop_price is not None:
            mod_data["stopPrice"] = stop_price
        if qty is not None:
            mod_data["orderQty"] = qty
        result = await self._post("/order/modifyorder", mod_data)
        logger.info(f"Modified order {order_id}")
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
        return await self._get("/position/list")

    async def get_open_orders(self) -> List[Dict]:
        """Get all open orders."""
        return await self._get("/order/list")

    async def get_fills(self) -> List[Dict]:
        """Get today's fills."""
        return await self._get("/fill/list")

    # ── Market Data (WebSocket) ──

    async def subscribe_market_data(self, symbol: str, callback: Callable):
        """Subscribe to real-time quotes for a symbol."""
        if not self._md_ws:
            await self._connect_md_websocket()

        self._callbacks.setdefault(symbol, []).append(callback)

        self._ws_request_id += 1
        sub_msg = f"md/subscribeQuote\n{self._ws_request_id}\n\n{json.dumps({'symbol': symbol})}"
        await self._md_ws.send(sub_msg)
        logger.info(f"Subscribed to market data: {symbol}")

    async def _connect_md_websocket(self):
        """Connect to market data WebSocket."""
        token = self.md_access_token or self.access_token
        self._md_ws = await websockets.connect(self.md_ws_url)

        # Wait for open frame
        msg = await self._md_ws.recv()
        if msg == "o":
            logger.debug("MD WebSocket open frame received")

        # Authenticate
        auth_msg = f"authorize\n1\n\n{token}"
        await self._md_ws.send(auth_msg)
        response = await self._md_ws.recv()
        logger.info(f"MD WebSocket connected")

        # Start heartbeat and listener
        self._heartbeat_task = asyncio.create_task(self._ws_heartbeat())
        asyncio.create_task(self._listen_md())

    async def _ws_heartbeat(self):
        """Send heartbeat responses to keep WebSocket alive."""
        while True:
            try:
                await asyncio.sleep(30)
                if self._md_ws and self._md_ws.open:
                    await self._md_ws.send("[]")
            except asyncio.CancelledError:
                break
            except Exception:
                break

    async def _listen_md(self):
        """Listen for market data messages."""
        try:
            async for message in self._md_ws:
                try:
                    if message == "h":
                        # Heartbeat from server
                        await self._md_ws.send("[]")
                        continue
                    if message.startswith("a"):
                        # Data frame - strip 'a' prefix and parse
                        self._process_md_message(message[1:])
                except Exception as e:
                    logger.error(f"Error processing MD message: {e}")
        except websockets.ConnectionClosed:
            logger.warning("MD WebSocket disconnected, reconnecting in 2s...")
            await asyncio.sleep(2)
            self._md_ws = None
            await self._connect_md_websocket()
            # Re-subscribe
            for symbol in self._callbacks:
                self._ws_request_id += 1
                sub_msg = f"md/subscribeQuote\n{self._ws_request_id}\n\n{json.dumps({'symbol': symbol})}"
                await self._md_ws.send(sub_msg)

    def _process_md_message(self, message: str):
        """Parse and dispatch market data messages."""
        try:
            frames = json.loads(message)
        except json.JSONDecodeError:
            return

        if not isinstance(frames, list):
            frames = [frames]

        for frame in frames:
            if not isinstance(frame, dict):
                continue

            event = frame.get("e", "")
            data = frame.get("d", frame)

            if event == "md" or "bid" in data or "trade" in data:
                contract_id = data.get("contractId", "")
                # Dispatch to all callbacks
                for symbol, cbs in self._callbacks.items():
                    for cb in cbs:
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
        tf_map = {
            "1min": (1, "Minute"),
            "5min": (5, "Minute"),
            "15min": (15, "Minute"),
            "30min": (30, "Minute"),
            "1hour": (1, "Hour"),
            "1day": (1, "Day"),
        }
        size, unit = tf_map.get(timeframe, (5, "Minute"))

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
