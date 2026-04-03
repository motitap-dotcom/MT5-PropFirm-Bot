"""
Tradovate API Client
Handles authentication, order management, and market data via REST + WebSocket.

Auth method: Web-style authentication (no API keys needed).
Uses appId="tradovate_trader(web)", cid=8, with encrypted password + HMAC.
CAPTCHA is handled automatically via Playwright headless browser.
Token auto-renews every 15 minutes before expiry.
"""

import asyncio
import base64
import hashlib
import hmac as hmac_mod
import json
import os
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

# HMAC key and fields for web-style auth (same as Tradovate web trader)
_HMAC_KEY = "1259-11e7-485a-aeae-9b6016579351"
_HMAC_FIELDS = ["chl", "deviceId", "name", "password", "appId"]


def _encrypt_password(name: str, password: str) -> str:
    """Tradovate's client-side password encoding (btoa of shifted+reversed)."""
    offset = len(name) % len(password)
    rearranged = password[offset:] + password[:offset]
    reversed_pw = rearranged[::-1]
    return base64.b64encode(reversed_pw.encode()).decode()


def _compute_hmac_sec(payload: dict) -> str:
    """Compute the HMAC-SHA256 'sec' field from the auth payload."""
    message = "".join(str(payload.get(f, "")) for f in _HMAC_FIELDS)
    return hmac_mod.new(
        _HMAC_KEY.encode(), message.encode(), hashlib.sha256
    ).hexdigest()


class TradovateClient:
    """Client for Tradovate REST and WebSocket APIs."""

    # API base URLs
    DEMO_URL = "https://demo.tradovateapi.com/v1"
    LIVE_URL = "https://live.tradovateapi.com/v1"
    DEMO_MD_URL = "https://md-demo.tradovateapi.com/v1"
    LIVE_MD_URL = "https://md.tradovateapi.com/v1"

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
        self.md_base_url = self.LIVE_MD_URL if live else self.DEMO_MD_URL
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
        """Initialize session and authenticate with robust multi-step fallback."""
        self.session = aiohttp.ClientSession()

        # Auth strategy order:
        # 1. Load saved token file → verify
        # 2. If saved token invalid → try renew it (works even if "expired" by our clock)
        # 3. Load env token → verify
        # 4. If env token invalid → try renew it
        # 5. Full user/password auth (may need CAPTCHA on new IP)

        connected = False

        # Step 1+2: Try saved token file (even expired ones - server may still accept renewal)
        saved_token, saved_md_token, saved_expiry = self._load_any_saved_token()
        if saved_token:
            self.access_token = saved_token
            self.md_access_token = saved_md_token
            self.token_expiry = saved_expiry
            logger.info("Loaded saved token from file, verifying...")
            try:
                await self._get_account_info()
                logger.info("Saved token is still valid")
                connected = True
            except Exception:
                logger.info("Saved token invalid, attempting renewal...")
                try:
                    renewed = await self._renew_token_safe()
                    if renewed:
                        await self._get_account_info()
                        logger.info("Token renewed successfully from saved token")
                        connected = True
                except Exception as e:
                    logger.warning(f"Renewal from saved token failed: {e}")

        # Step 3+4: Try env token
        if not connected:
            import os
            preset_token = os.environ.get("TRADOVATE_ACCESS_TOKEN", "").strip()
            if preset_token:
                self.access_token = preset_token
                self.md_access_token = preset_token
                self.token_expiry = time.time() + 86400
                logger.info("Trying pre-set access token from environment...")
                try:
                    await self._get_account_info()
                    logger.info("Environment token is valid")
                    self._save_token()
                    connected = True
                except Exception:
                    logger.info("Environment token invalid, attempting renewal...")
                    try:
                        renewed = await self._renew_token_safe()
                        if renewed:
                            await self._get_account_info()
                            logger.info("Token renewed successfully from env token")
                            connected = True
                    except Exception as e:
                        logger.warning(f"Renewal from env token failed: {e}")

        # Step 5: Full user/password auth (last resort)
        if not connected:
            logger.info("All tokens failed, attempting user/password authentication...")
            await self._authenticate()
            await self._get_account_info()

        self._token_obtained_at = time.time()
        self._save_token()
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
        Authenticate with multi-step fallback:
        1. Web-style auth with encrypted password + HMAC (try live endpoint first)
        2. Web-style auth on demo endpoint
        3. Playwright headless browser (handles CAPTCHA automatically)
        """
        # Try web auth on live endpoint first (works better for prop firms)
        data = await self._try_web_auth(f"{self.LIVE_URL}/auth/accesstokenrequest")
        if data is None and "demo" in self.base_url:
            data = await self._try_web_auth(f"{self.base_url}/auth/accesstokenrequest")

        # If web auth failed (CAPTCHA), try Playwright browser
        if data is None:
            logger.info("Web auth failed, trying Playwright browser login...")
            data = await self._try_browser_auth()

        if data is None:
            raise ConnectionError(
                "All authentication methods failed. "
                "Ensure Playwright is installed: pip install playwright && playwright install chromium"
            )

        self.access_token = data["accessToken"]
        self.md_access_token = data.get("mdAccessToken", self.access_token)
        self._parse_expiry(data.get("expirationTime", ""))
        self._save_token()
        logger.info("Authenticated successfully")

    async def _try_web_auth(self, url: str) -> Optional[Dict]:
        """Try web-style auth with encrypted password + HMAC."""
        if not self.username or not self.password:
            return None

        encrypted_pw = _encrypt_password(self.username, self.password)
        payload = {
            "name": self.username,
            "password": encrypted_pw,
            "appId": self.WEB_APP_ID,
            "appVersion": self.WEB_APP_VERSION,
            "deviceId": self.device_id,
            "cid": self.WEB_CID,
            "sec": "",
            "chl": "",
            "organization": self.organization,
        }
        payload["sec"] = _compute_hmac_sec(payload)

        try:
            async with self.session.post(url, json=payload) as resp:
                if resp.content_type != "application/json":
                    return None
                data = await resp.json()

            if "accessToken" in data:
                return data

            if "p-ticket" in data:
                p_captcha = data.get("p-captcha", False)
                if p_captcha:
                    logger.warning(f"CAPTCHA required on {url}, will try browser auth")
                    return None
                # Wait and retry (no CAPTCHA, just rate limit)
                p_time = data.get("p-time", 15)
                logger.info(f"Waiting {p_time}s before retry (p-ticket received)...")
                await asyncio.sleep(p_time)
                payload["p-ticket"] = data["p-ticket"]
                payload["sec"] = _compute_hmac_sec(payload)
                async with self.session.post(url, json=payload) as resp:
                    data = await resp.json()
                if "accessToken" in data:
                    return data

        except Exception as e:
            logger.warning(f"Web auth failed on {url}: {e}")
        return None

    async def _try_browser_auth(self) -> Optional[Dict]:
        """Use Playwright headless browser to authenticate (handles CAPTCHA)."""
        try:
            from playwright.async_api import async_playwright
        except ImportError:
            logger.error(
                "Playwright not installed. Install with:\n"
                "pip install playwright && playwright install chromium"
            )
            return None

        trader_url = "https://trader.tradovate.com"
        captured = {}

        def _on_response(response):
            if captured:
                return
            try:
                ct = response.headers.get("content-type", "")
                if "json" not in ct:
                    return
                # Use sync callback - just schedule the async read
                asyncio.ensure_future(_check_response(response))
            except Exception:
                pass

        async def _check_response(response):
            if captured:
                return
            try:
                data = await response.json()
                if isinstance(data, dict) and "accessToken" in data:
                    captured.update(data)
            except Exception:
                pass

        for attempt in range(1, 3):
            browser = None
            try:
                pw = await async_playwright().start()
                browser = await pw.chromium.launch(
                    headless=True,
                    args=[
                        "--no-sandbox",
                        "--disable-blink-features=AutomationControlled",
                        "--disable-dev-shm-usage",
                        "--disable-gpu",
                    ],
                )
                ctx = await browser.new_context(
                    viewport={"width": 1280, "height": 720},
                    user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/121.0.0.0",
                )
                await ctx.add_init_script(
                    "Object.defineProperty(navigator,'webdriver',{get:()=>undefined});"
                )
                page = await ctx.new_page()
                page.on("response", _on_response)

                await page.goto(trader_url, timeout=60000, wait_until="domcontentloaded")
                await page.wait_for_timeout(10000)

                text_input = await page.query_selector('input[type="text"]')
                pass_input = await page.query_selector('input[type="password"]')
                if text_input and pass_input:
                    await text_input.fill(self.username)
                    await pass_input.fill(self.password)
                    await page.wait_for_timeout(500)
                    for btn in await page.query_selector_all("button"):
                        btn_text = await btn.inner_text()
                        if "login" in (btn_text or "").lower():
                            await btn.click()
                            break
                    # Wait for token response
                    for _ in range(60):
                        if captured:
                            break
                        await page.wait_for_timeout(1000)

                await browser.close()
                await pw.stop()
                browser = None

                if captured and "accessToken" in captured:
                    logger.info("Browser auth succeeded - got token via Playwright")
                    return captured
            except Exception as e:
                logger.warning(f"Browser auth attempt {attempt} failed: {e}")
                if browser:
                    await browser.close()
            if attempt < 2:
                await asyncio.sleep(10)

        return None

    async def _renew_token_safe(self) -> bool:
        """
        Renew access token without falling back to _authenticate().
        Tries both demo and live endpoints (like the working bot).
        Returns True if renewal succeeded, False otherwise.
        """
        if not self.access_token:
            return False

        # Try current base URL first, then the other one
        urls = [f"{self.base_url}/auth/renewaccesstoken"]
        if "demo" in self.base_url:
            urls.append(f"{self.LIVE_URL}/auth/renewaccesstoken")
        else:
            urls.append(f"{self.DEMO_URL}/auth/renewaccesstoken")

        for url in urls:
            try:
                async with self.session.post(url, headers=self._headers()) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        if "accessToken" in data:
                            self.access_token = data["accessToken"]
                            self.md_access_token = data.get("mdAccessToken", self.access_token)
                            self._parse_expiry(data.get("expirationTime", ""))
                            self._save_token()
                            self._token_obtained_at = time.time()
                            logger.info(f"Token renewed successfully via {url}")
                            return True
            except Exception as e:
                logger.debug(f"Renewal failed on {url}: {e}")

        logger.warning("Token renewal failed on all endpoints")
        return False

    async def _renew_token(self):
        """Renew token, fall back to full auth if renewal fails."""
        if await self._renew_token_safe():
            return
        logger.warning("Renewal failed, falling back to full authentication...")
        await self._authenticate()

    async def _ensure_token(self):
        """Refresh token proactively - renew 15 min before expiry (tokens last ~80 min)."""
        remaining = self.token_expiry - time.time()

        if remaining < 900:  # Less than 15 minutes left
            logger.info(f"Token expiring in {remaining/60:.0f}min, renewing...")
            if not await self._renew_token_safe():
                # Renewal failed - full re-auth
                self.access_token = None
                self.md_access_token = None
                await self._authenticate()

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
        """Save token to file and .env for persistence across restarts."""
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
            logger.warning(f"Could not save token file: {e}")

        # Also update .env so restarts use the fresh token
        try:
            import os
            env_path = Path(os.environ.get("BOT_ROOT", ".")) / ".env"
            if env_path.exists():
                lines = env_path.read_text().splitlines()
                new_lines = []
                token_updated = False
                for line in lines:
                    if line.startswith("TRADOVATE_ACCESS_TOKEN="):
                        new_lines.append(f"TRADOVATE_ACCESS_TOKEN={self.access_token}")
                        token_updated = True
                    else:
                        new_lines.append(line)
                if not token_updated:
                    new_lines.append(f"TRADOVATE_ACCESS_TOKEN={self.access_token}")
                env_path.write_text("\n".join(new_lines) + "\n")
                logger.debug("Updated .env with fresh token")
        except Exception as e:
            logger.debug(f"Could not update .env: {e}")

    def _load_saved_token(self) -> bool:
        """Load token from file. Returns True if valid (non-expired) token loaded."""
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

    def _load_any_saved_token(self):
        """Load token from file even if expired (for renewal attempts).
        Returns (access_token, md_access_token, expiry) or (None, None, 0)."""
        try:
            if not TOKEN_FILE.exists():
                return None, None, 0
            data = json.loads(TOKEN_FILE.read_text())
            token = data.get("access_token")
            if token:
                logger.debug(f"Loaded saved token (expiry: {data.get('expiry', 0)}, saved: {data.get('saved_at', '?')})")
                return token, data.get("md_access_token"), data.get("expiry", 0)
        except Exception as e:
            logger.debug(f"Could not load saved token: {e}")
        return None, None, 0

    def _headers(self) -> Dict[str, str]:
        return {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
        }

    def _md_headers(self) -> Dict[str, str]:
        """Headers for market data endpoints (uses md_access_token if available)."""
        token = self.md_access_token or self.access_token
        return {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }

    # ── REST Helpers ──

    async def _get(self, endpoint: str) -> Any:
        """GET request with automatic token refresh on 401."""
        await self._ensure_token()
        async with self.session.get(f"{self.base_url}{endpoint}",
                                     headers=self._headers()) as resp:
            if resp.status == 401:
                logger.warning(f"GET {endpoint} got 401, renewing token and retrying...")
                await self._renew_token()
                async with self.session.get(f"{self.base_url}{endpoint}",
                                             headers=self._headers()) as resp2:
                    if resp2.status != 200:
                        text = await resp2.text()
                        raise Exception(f"GET {endpoint} failed ({resp2.status}): {text}")
                    return await resp2.json()
            if resp.status != 200:
                text = await resp.text()
                raise Exception(f"GET {endpoint} failed ({resp.status}): {text}")
            return await resp.json()

    async def _post(self, endpoint: str, data: Dict = None) -> Any:
        """POST request with automatic token refresh on 401."""
        await self._ensure_token()
        # Market data endpoints go to the MD server
        if endpoint.startswith("/md/"):
            base = self.md_base_url
            headers = self._md_headers()
        else:
            base = self.base_url
            headers = self._headers()
        async with self.session.post(f"{base}{endpoint}",
                                      headers=headers,
                                      json=data or {}) as resp:
            if resp.status == 401:
                logger.warning(f"POST {endpoint} got 401, renewing token and retrying...")
                await self._renew_token()
                headers = self._md_headers() if endpoint.startswith("/md/") else self._headers()
                async with self.session.post(f"{base}{endpoint}",
                                              headers=headers,
                                              json=data or {}) as resp2:
                    if resp2.status != 200:
                        text = await resp2.text()
                        raise Exception(f"POST {endpoint} failed ({resp2.status}): {text}")
                    return await resp2.json()
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
            "1min": (1, "MinuteBar"),
            "5min": (5, "MinuteBar"),
            "15min": (15, "MinuteBar"),
            "30min": (30, "MinuteBar"),
            "1hour": (60, "MinuteBar"),
            "1day": (1, "DailyBar"),
        }
        size, underlying = tf_map.get(timeframe, (5, "MinuteBar"))

        result = await self._post("/md/getChart", {
            "symbol": symbol,
            "chartDescription": {
                "underlyingType": underlying,
                "elementSize": size,
                "elementSizeUnit": "UnderlyingUnits",
                "withHistogram": False,
            },
            "timeRange": {
                "asMuchAsElements": count,
            },
        })
        return result.get("bars", [])
