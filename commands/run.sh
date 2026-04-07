#!/bin/bash
# Trigger: v121 - Direct browser auth for TradeDay
cd /root/MT5-PropFirm-Bot
source .env

echo "=== TradeDay Auth v121 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "User: $TRADOVATE_USER"

# Use Tradovate-Bot's venv with Playwright
/root/tradovate-bot/venv/bin/python3 << PYEOF
import sys, os, json, base64, hashlib, hmac, requests, time
sys.path.insert(0, "/root/tradovate-bot")

username = "$TRADOVATE_USER"
password = "$TRADOVATE_PASS"

# 1. Try web auth first (encrypted password + HMAC)
print("=== Trying web auth ===")
offset = len(username) % len(password)
rearranged = password[offset:] + password[:offset]
encrypted_pw = base64.b64encode(rearranged[::-1].encode()).decode()

payload = {
    "name": username, "password": encrypted_pw,
    "appId": "tradovate_trader(web)", "appVersion": "3.260220.0",
    "deviceId": "futures-bot-td", "cid": 8, "sec": "", "chl": "",
    "organization": "",
}
fields = ["chl", "deviceId", "name", "password", "appId"]
msg = "".join(str(payload.get(f, "")) for f in fields)
payload["sec"] = hmac.new("1259-11e7-485a-aeae-9b6016579351".encode(), msg.encode(), hashlib.sha256).hexdigest()

url = "https://demo.tradovateapi.com/v1/auth/accesstokenrequest"
r = requests.post(url, json=payload, timeout=15)
data = r.json()

if "accessToken" in data:
    print("Web auth SUCCESS!")
    token_data = data
elif "p-ticket" in data and not data.get("p-captcha"):
    print(f"p-ticket without captcha, waiting {data.get('p-time',15)}s...")
    time.sleep(data.get("p-time", 15) + 1)
    payload["p-ticket"] = data["p-ticket"]
    r2 = requests.post(url, json=payload, timeout=15)
    data2 = r2.json()
    if "accessToken" in data2:
        print("Web auth SUCCESS after p-ticket!")
        token_data = data2
    else:
        token_data = None
        print(f"p-ticket retry failed: {data2}")
else:
    token_data = None
    captcha = data.get("p-captcha", False)
    print(f"Web auth needs CAPTCHA: {captcha}")

    # 2. Try browser auth (Playwright)
    print("\n=== Trying Playwright browser auth ===")
    try:
        import asyncio
        from playwright.async_api import async_playwright

        async def browser_login():
            captured = None
            async with async_playwright() as p:
                browser = await p.chromium.launch(headless=True)
                page = await browser.new_page()

                async def on_response(resp):
                    nonlocal captured
                    if "accesstoken" in resp.url.lower() or "auth" in resp.url.lower():
                        try:
                            d = await resp.json()
                            if isinstance(d, dict) and "accessToken" in d:
                                captured = d
                        except:
                            pass
                page.on("response", on_response)

                await page.goto("https://trader.tradovate.com/welcome", timeout=30000)
                await asyncio.sleep(2)
                await page.fill('input[name="name"]', username, timeout=10000)
                await page.fill('input[name="password"]', password, timeout=10000)
                await page.click('button[type="submit"]', timeout=10000)
                print("Login submitted, waiting 45s for token...")
                for i in range(45):
                    if captured: break
                    await asyncio.sleep(1)
                await browser.close()
            return captured

        token_data = asyncio.run(browser_login())
        if token_data:
            print("Browser auth SUCCESS!")
        else:
            print("Browser auth: no token captured")
    except Exception as e:
        print(f"Browser auth error: {e}")

# Save if we got a token
if token_data and "accessToken" in token_data:
    path = "/root/MT5-PropFirm-Bot/configs/.tradovate_token.json"
    with open(path, "w") as f:
        json.dump(token_data, f, indent=2)
    print(f"\nToken saved!")
    print(f"Account: {token_data.get('accountSpec', '?')}")
    print(f"Expires: {token_data.get('expirationTime', '?')}")

    # List accounts
    headers = {"Authorization": f"Bearer {token_data['accessToken']}"}
    ar = requests.get("https://demo.tradovateapi.com/v1/account/list", headers=headers, timeout=10)
    if ar.status_code == 200:
        print("\nAll accounts:")
        for a in ar.json():
            print(f"  {a.get('name')} id={a.get('id')} active={a.get('active')}")
else:
    print("\nFAILED to get token")
PYEOF
