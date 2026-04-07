#!/bin/bash
# Trigger: v131 - Get token + verify
cd /root/MT5-PropFirm-Bot
source .env
echo "=== v131 ==="
echo "$(date -u '+%Y-%m-%d %H:%M UTC')"

# Get fresh token via browser
/root/tradovate-bot/venv/bin/python3 << PYEOF
import asyncio, json
async def main():
    from playwright.async_api import async_playwright
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
        await page.fill('input[type="text"]', "$TRADOVATE_USER", timeout=15000)
        await page.fill('input[type="password"]', "$TRADOVATE_PASS", timeout=15000)
        await page.click('button:has-text("Log")', timeout=15000)
        for i in range(30):
            if captured: break
            await asyncio.sleep(1)
        await browser.close()
    if captured:
        with open("/root/MT5-PropFirm-Bot/configs/.tradovate_token.json", "w") as f:
            json.dump(captured, f, indent=2)
        print(f"TOKEN OK - {captured.get('expirationTime','?')}")
    else:
        print("NO TOKEN")
asyncio.run(main())
PYEOF

# Quick restart
systemctl restart futures-bot 2>/dev/null
sleep 8
echo "Service: $(systemctl is-active futures-bot)"
echo ""
tail -15 logs/bot.log 2>/dev/null
