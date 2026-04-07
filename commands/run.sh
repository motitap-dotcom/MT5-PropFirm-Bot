#!/bin/bash
# Trigger: v124 - Browser auth with flexible selectors + page dump
cd /root/MT5-PropFirm-Bot
source .env

echo "=== Browser Auth v124 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"

# Run inline - shorter, no background needed since v122 showed it completes
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
                        print(f"TOKEN CAPTURED!")
            except:
                pass
        page.on("response", on_resp)

        print("Opening login page...")
        await page.goto("https://trader.tradovate.com/welcome", timeout=60000)
        await asyncio.sleep(5)

        # Dump page structure to find correct selectors
        print(f"URL: {page.url}")
        inputs = await page.query_selector_all("input")
        print(f"Found {len(inputs)} inputs:")
        for i, inp in enumerate(inputs):
            t = await inp.get_attribute("type") or ""
            n = await inp.get_attribute("name") or ""
            p_attr = await inp.get_attribute("placeholder") or ""
            c = await inp.get_attribute("class") or ""
            print(f"  [{i}] type={t} name={n} placeholder={p_attr}")

        buttons = await page.query_selector_all("button")
        print(f"Found {len(buttons)} buttons:")
        for i, btn in enumerate(buttons):
            txt = (await btn.text_content() or "").strip()[:30]
            t = await btn.get_attribute("type") or ""
            print(f"  [{i}] type={t} text={txt}")

        # Try to fill using various selectors
        filled = False
        for sel in ['input[name="name"]', 'input[name="username"]', 'input[name="email"]',
                     'input[type="text"]', 'input[type="email"]', 'input:first-of-type']:
            try:
                el = await page.query_selector(sel)
                if el:
                    await el.fill(username)
                    print(f"Username filled via: {sel}")
                    filled = True
                    break
            except:
                pass

        for sel in ['input[name="password"]', 'input[type="password"]']:
            try:
                el = await page.query_selector(sel)
                if el:
                    await el.fill(password)
                    print(f"Password filled via: {sel}")
                    break
            except:
                pass

        # Click submit
        for sel in ['button[type="submit"]', 'button:has-text("Log")', 'button:has-text("Sign")']:
            try:
                el = await page.query_selector(sel)
                if el:
                    await el.click()
                    print(f"Clicked: {sel}")
                    break
            except:
                pass

        print("Waiting 30s for token...")
        for i in range(30):
            if captured: break
            await asyncio.sleep(1)

        await browser.close()

    if captured:
        path = "/root/MT5-PropFirm-Bot/configs/.tradovate_token.json"
        with open(path, "w") as f:
            json.dump(captured, f, indent=2)
        print(f"Token saved! Account: {captured.get('accountSpec','?')}")
    else:
        print("No token captured")

asyncio.run(main())
PYEOF
