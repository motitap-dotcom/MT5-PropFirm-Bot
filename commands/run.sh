#!/bin/bash
# Trigger: v112 - Use Tradovate-Bot's Playwright + venv for browser auth
cd /root/MT5-PropFirm-Bot
source .env

echo "=== Browser Auth v112 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "User: $TRADOVATE_USER"

# Use the other bot's venv which already has Playwright installed
PYTHON="/root/tradovate-bot/venv/bin/python3"
if [ ! -f "$PYTHON" ]; then
    echo "ERROR: Tradovate-Bot venv not found"
    exit 1
fi
echo "Using Python: $PYTHON"
echo "Playwright check: $($PYTHON -c 'import playwright; print("OK")' 2>&1)"

$PYTHON << 'PYEOF'
import os, json, asyncio

async def browser_auth():
    from playwright.async_api import async_playwright

    username = os.environ.get("TRADOVATE_USER", "")
    password = os.environ.get("TRADOVATE_PASS", "")

    print(f"Launching browser for {username}...")
    token_data = None

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()
        page = await context.new_page()

        async def handle_response(response):
            nonlocal token_data
            url = response.url.lower()
            if "accesstoken" in url or "auth" in url:
                try:
                    data = await response.json()
                    if isinstance(data, dict) and "accessToken" in data:
                        token_data = data
                        print(f"TOKEN CAPTURED!")
                except:
                    pass

        page.on("response", handle_response)

        print("Opening Tradovate...")
        await page.goto("https://trader.tradovate.com/welcome", timeout=30000)
        await asyncio.sleep(3)

        print("Filling login form...")
        try:
            await page.fill('input[name="name"]', username, timeout=10000)
            await page.fill('input[name="password"]', password, timeout=10000)
            await page.click('button[type="submit"]', timeout=10000)
            print("Login submitted")
        except Exception as e:
            print(f"Selector error: {e}")
            # Try alternative selectors
            try:
                inputs = await page.query_selector_all('input')
                print(f"Found {len(inputs)} inputs")
                for i, inp in enumerate(inputs):
                    inp_type = await inp.get_attribute("type")
                    inp_name = await inp.get_attribute("name")
                    print(f"  Input {i}: type={inp_type} name={inp_name}")
                buttons = await page.query_selector_all('button')
                print(f"Found {len(buttons)} buttons")
            except:
                pass

        print("Waiting for token (45s)...")
        for i in range(45):
            if token_data:
                break
            await asyncio.sleep(1)
            if i % 10 == 9:
                print(f"  ...{i+1}s")

        print(f"Final URL: {page.url}")
        await browser.close()

    if token_data:
        print(f"\nSUCCESS!")
        print(f"Account: {token_data.get('accountSpec', '?')}")
        print(f"Expires: {token_data.get('expirationTime', '?')}")
        token_path = "/root/MT5-PropFirm-Bot/configs/.tradovate_token.json"
        with open(token_path, "w") as f:
            json.dump(token_data, f, indent=2)
        print(f"Token saved to {token_path}")
    else:
        print("\nNo token captured.")

asyncio.run(browser_auth())
PYEOF
