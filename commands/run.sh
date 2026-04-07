#!/bin/bash
# Trigger: v122 - Launch browser auth in background, check result later
cd /root/MT5-PropFirm-Bot
source .env

echo "=== Background Browser Auth v122 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"

# Write the browser auth script
cat > /tmp/get_tradeday_token.py << 'PYEOF'
import asyncio, json, os, sys

async def main():
    from playwright.async_api import async_playwright

    username = os.environ.get("TRADOVATE_USER", "")
    password = os.environ.get("TRADOVATE_PASS", "")
    result_file = "/root/MT5-PropFirm-Bot/configs/.tradovate_token.json"
    log_file = "/tmp/browser_auth.log"

    with open(log_file, "w") as log:
        log.write(f"Starting browser auth for {username}\n")
        captured = None

        try:
            async with async_playwright() as p:
                browser = await p.chromium.launch(headless=True)
                page = await browser.new_page()

                async def on_response(resp):
                    nonlocal captured
                    try:
                        if "accesstoken" in resp.url.lower():
                            d = await resp.json()
                            if isinstance(d, dict) and "accessToken" in d:
                                captured = d
                                log.write(f"TOKEN CAPTURED!\n")
                    except:
                        pass
                page.on("response", on_response)

                log.write("Opening Tradovate...\n")
                await page.goto("https://trader.tradovate.com/welcome", timeout=60000)
                await asyncio.sleep(3)

                log.write("Filling form...\n")
                await page.fill('input[name="name"]', username, timeout=15000)
                await page.fill('input[name="password"]', password, timeout=15000)
                await page.click('button[type="submit"]', timeout=15000)
                log.write("Submitted, waiting 60s...\n")

                for i in range(60):
                    if captured:
                        break
                    await asyncio.sleep(1)

                log.write(f"Final URL: {page.url}\n")
                await page.screenshot(path="/tmp/tradovate_login.png")
                await browser.close()

            if captured:
                with open(result_file, "w") as f:
                    json.dump(captured, f, indent=2)
                log.write(f"SUCCESS! Saved to {result_file}\n")
                log.write(f"Account: {captured.get('accountSpec', '?')}\n")
            else:
                log.write("FAILED: no token captured\n")
        except Exception as e:
            log.write(f"ERROR: {e}\n")

asyncio.run(main())
PYEOF

# Launch in background with Tradovate-Bot's venv
echo "Launching browser auth in background..."
nohup /root/tradovate-bot/venv/bin/python3 /tmp/get_tradeday_token.py > /tmp/browser_auth_stdout.log 2>&1 &
BG_PID=$!
echo "PID: $BG_PID"

# Wait a bit and check if it's running
sleep 3
if kill -0 $BG_PID 2>/dev/null; then
    echo "Script is running (PID $BG_PID)"
    echo "Will check result in next status check"
else
    echo "Script exited already"
    cat /tmp/browser_auth.log 2>/dev/null
fi

echo ""
echo "=== Current logs ==="
cat /tmp/browser_auth.log 2>/dev/null || echo "No log yet"
