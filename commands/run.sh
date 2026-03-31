#!/bin/bash
# Trigger: v92 - Debug password + try browser auth
cd /root/MT5-PropFirm-Bot

echo "=== AUTH DEBUG ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

PY="python3"
[ -d "venv" ] && PY="venv/bin/python3"

# Check password from workflow env vs .env file
echo "=== Password Debug ==="
echo "From workflow env var:"
echo "  TRADOVATE_USER=${TRADOVATE_USER}"
echo "  TRADOVATE_PASS length: ${#TRADOVATE_PASS}"
echo "  TRADOVATE_PASS first/last char: ${TRADOVATE_PASS:0:1}...${TRADOVATE_PASS: -1}"
echo ""

echo "From .env file:"
ENV_PASS=$(grep TRADOVATE_PASS .env | cut -d= -f2-)
echo "  .env TRADOVATE_PASS length: ${#ENV_PASS}"
echo "  .env first/last char: ${ENV_PASS:0:1}...${ENV_PASS: -1}"
echo ""

# Test auth using WORKFLOW env vars directly (not .env)
echo "=== Test 1: Auth with workflow env vars ==="
$PY << PYEOF
import os, json, base64, hashlib, hmac as hmac_mod, uuid, requests

username = "${TRADOVATE_USER}"
password = "${TRADOVATE_PASS}"
print(f"Using: username={username}, pw_len={len(password)}")

device_id = str(uuid.uuid4())

# Plain password test
payload = {
    "name": username, "password": password,
    "appId": "tradovate_trader(web)", "appVersion": "3.260220.0",
    "deviceId": device_id, "cid": 8, "sec": "", "organization": "",
}

for url_name, url in [("demo", "https://demo.tradovateapi.com/v1/auth/accesstokenrequest"),
                       ("live", "https://live.tradovateapi.com/v1/auth/accesstokenrequest")]:
    try:
        resp = requests.post(url, json=payload, timeout=15)
        data = resp.json()
        if "accessToken" in data:
            print(f"  {url_name}: SUCCESS!")
            token_data = {"access_token": data["accessToken"],
                          "md_access_token": data.get("mdAccessToken", data["accessToken"]),
                          "expiry": __import__('time').time() + 86400}
            with open("configs/.tradovate_token.json", "w") as f:
                json.dump(token_data, f, indent=2)
            print(f"  Token saved!")
        elif "p-ticket" in data:
            print(f"  {url_name}: p-ticket (captcha={data.get('p-captcha', False)})")
        else:
            print(f"  {url_name}: {data.get('errorText', str(data)[:150])}")
    except Exception as e:
        print(f"  {url_name}: ERROR: {e}")
PYEOF

echo ""

# Test 2: Browser auth (bypasses API auth entirely)
echo "=== Test 2: Browser Auth (Playwright) ==="
$PY << PYEOF
import os, json, time

username = "${TRADOVATE_USER}"
password = "${TRADOVATE_PASS}"

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("Playwright not available")
    exit(1)

trader_url = "https://trader.tradovate.com"
captured = {}

def on_response(response):
    if captured:
        return
    try:
        ct = response.headers.get("content-type", "")
        if "json" not in ct:
            return
        data = response.json()
        if isinstance(data, dict) and "accessToken" in data:
            captured.update(data)
    except:
        pass

print(f"Launching browser to {trader_url}...")
try:
    with sync_playwright() as pw:
        browser = pw.chromium.launch(
            headless=True,
            args=["--no-sandbox", "--disable-blink-features=AutomationControlled",
                   "--disable-dev-shm-usage", "--disable-gpu"],
        )
        ctx = browser.new_context(
            viewport={"width": 1280, "height": 720},
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/121.0.0.0 Safari/537.36",
            ignore_https_errors=True,
        )
        ctx.add_init_script("Object.defineProperty(navigator,'webdriver',{get:()=>undefined});")
        page = ctx.new_page()
        page.on("response", on_response)

        page.goto(trader_url, timeout=60000, wait_until="domcontentloaded")
        print(f"Page loaded. Title: {page.title()}")
        page.wait_for_timeout(10000)

        text_input = page.query_selector('input[type="text"]')
        pass_input = page.query_selector('input[type="password"]')

        if text_input and pass_input:
            print("Login form found, filling...")
            text_input.fill(username)
            pass_input.fill(password)
            page.wait_for_timeout(500)

            clicked = False
            for btn in page.query_selector_all("button"):
                btn_text = (btn.inner_text() or "").strip().lower()
                if any(w in btn_text for w in ("login", "sign in", "log in")):
                    print(f"Clicking: {btn_text}")
                    btn.click()
                    clicked = True
                    break
            if not clicked:
                page.keyboard.press("Enter")
                print("Pressed Enter")

            print("Waiting for token (up to 60s)...")
            for i in range(60):
                if captured:
                    break
                page.wait_for_timeout(1000)
                if i == 15:
                    print(f"  Still waiting... URL: {page.url}")
                if i == 30:
                    # Check for error messages
                    error_el = page.query_selector('.error, .alert, [class*=error]')
                    if error_el:
                        print(f"  Error on page: {error_el.inner_text()}")
        else:
            print(f"No login form found. URL: {page.url}")
            inputs = page.query_selector_all("input")
            print(f"Found {len(inputs)} input elements")

        browser.close()

    if captured and "accessToken" in captured:
        print(f"BROWSER AUTH SUCCESS! userId={captured.get('userId')}")
        token_data = {"access_token": captured["accessToken"],
                      "md_access_token": captured.get("mdAccessToken", captured["accessToken"]),
                      "expiry": time.time() + 86400}
        with open("configs/.tradovate_token.json", "w") as f:
            json.dump(token_data, f, indent=2)
        print("Token saved!")
    else:
        print("Browser auth: no token captured")
except Exception as e:
    print(f"Browser auth error: {e}")

PYEOF

echo ""
echo "=== END ==="
