#!/bin/bash
# Trigger: v111 - Browser auth via Playwright (bypass CAPTCHA)
cd /root/MT5-PropFirm-Bot

echo "=== Browser Auth v111 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"

# Install playwright if needed
echo "Checking Playwright..."
pip3 install playwright -q 2>&1 | tail -2
python3 -m playwright install chromium 2>&1 | tail -3

source .env
echo "User: $TRADOVATE_USER"

python3 << 'PYEOF'
import os, json, asyncio

async def browser_auth():
    from playwright.async_api import async_playwright

    username = os.environ.get("TRADOVATE_USER", "")
    password = os.environ.get("TRADOVATE_PASS", "")

    if not username or not password:
        print("ERROR: credentials not set")
        return

    print(f"Launching browser for {username}...")
    token_data = None

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()
        page = await context.new_page()

        # Intercept network responses to catch the token
        async def handle_response(response):
            nonlocal token_data
            if "accesstokenrequest" in response.url or "renewaccesstoken" in response.url:
                try:
                    data = await response.json()
                    if "accessToken" in data:
                        token_data = data
                        print(f"TOKEN CAPTURED from {response.url}")
                except:
                    pass

        page.on("response", handle_response)

        # Go to Tradovate login
        print("Opening Tradovate login page...")
        await page.goto("https://trader.tradovate.com/welcome", timeout=30000)
        await page.wait_for_load_state("networkidle", timeout=15000)

        # Fill credentials
        print("Filling credentials...")
        try:
            # Try common selectors for username/password
            for selector in ['input[name="name"]', 'input[name="username"]', '#username', 'input[type="text"]']:
                el = await page.query_selector(selector)
                if el:
                    await el.fill(username)
                    print(f"  Username filled via {selector}")
                    break

            for selector in ['input[name="password"]', '#password', 'input[type="password"]']:
                el = await page.query_selector(selector)
                if el:
                    await el.fill(password)
                    print(f"  Password filled via {selector}")
                    break

            # Click login button
            for selector in ['button[type="submit"]', 'button:has-text("Log In")', 'button:has-text("Sign In")', '.login-button']:
                el = await page.query_selector(selector)
                if el:
                    await el.click()
                    print(f"  Clicked login via {selector}")
                    break

            # Wait for auth response
            print("Waiting for auth response (30s)...")
            for i in range(30):
                if token_data:
                    break
                await asyncio.sleep(1)

        except Exception as e:
            print(f"Browser interaction error: {e}")

        # Take screenshot for debug
        await page.screenshot(path="/tmp/tradovate_login.png")
        print(f"Screenshot saved to /tmp/tradovate_login.png")
        print(f"Page URL: {page.url}")

        await browser.close()

    if token_data:
        print("\nSUCCESS!")
        print(f"Account: {token_data.get('accountSpec', '?')}")
        print(f"Expires: {token_data.get('expirationTime', '?')}")
        with open("configs/.tradovate_token.json", "w") as f:
            json.dump(token_data, f, indent=2)
        print("Token saved!")
    else:
        print("\nNo token captured. Login may have failed or page structure changed.")

asyncio.run(browser_auth())
PYEOF
