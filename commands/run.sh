#!/bin/bash
# Trigger: v128 - Browser auth + save token + check
cd /root/MT5-PropFirm-Bot
source .env

echo "=== Get Token & Start v128 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"

# Browser auth using Tradovate-Bot's Playwright
/root/tradovate-bot/venv/bin/python3 << PYEOF
import asyncio, json, os

async def main():
    from playwright.async_api import async_playwright
    username = "$TRADOVATE_USER"
    password = "$TRADOVATE_PASS"
    captured = None

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        async def on_resp(resp):
            nonlocal captured
            try:
                if "auth" in resp.url.lower() and resp.status == 200:
                    d = await resp.json()
                    if isinstance(d, dict) and "accessToken" in d:
                        captured = d
            except: pass
        page.on("response", on_resp)
        await page.goto("https://trader.tradovate.com/welcome", timeout=60000)
        await asyncio.sleep(5)
        await page.fill('input[type="text"]', username, timeout=15000)
        await page.fill('input[type="password"]', password, timeout=15000)
        await page.click('button:has-text("Log")', timeout=15000)
        for i in range(30):
            if captured: break
            await asyncio.sleep(1)
        await browser.close()

    if captured:
        with open("/root/MT5-PropFirm-Bot/configs/.tradovate_token.json", "w") as f:
            json.dump(captured, f, indent=2)
        print(f"TOKEN SAVED! Account: {captured.get('accountSpec','?')}")
        print(f"Expires: {captured.get('expirationTime','?')}")
    else:
        print("FAILED to get token")

asyncio.run(main())
PYEOF

echo ""
echo "=== Token check ==="
[ -f configs/.tradovate_token.json ] && echo "Token file EXISTS" || echo "Token file MISSING"
