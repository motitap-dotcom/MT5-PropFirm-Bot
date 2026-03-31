#!/bin/bash
# Trigger: v94 - Browser auth to get token + restart bot
cd /root/MT5-PropFirm-Bot

echo "=== BROWSER AUTH + RESTART ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

# Stop bot first to avoid rate limiting
systemctl stop futures-bot 2>/dev/null
echo "Bot stopped"
echo ""

# Wait 30s for rate limit to cool down
echo "Waiting 30s for rate limit cooldown..."
sleep 30

PY="python3"
[ -d "venv" ] && PY="venv/bin/python3"

# Run browser auth
echo "=== Running Browser Auth ==="
$PY << PYEOF
import json, time, os

username = "${TRADOVATE_USER}"
password = "${TRADOVATE_PASS}"

try:
    from playwright.sync_api import sync_playwright
    print("Playwright loaded OK")
except ImportError:
    print("ERROR: Playwright not available")
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
            print(f"TOKEN CAPTURED! userId={data.get('userId')}")
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

        page.goto(trader_url, timeout=90000, wait_until="domcontentloaded")
        print(f"Page loaded. Title: {page.title()}")
        print(f"URL: {page.url}")
        page.wait_for_timeout(15000)

        text_input = page.query_selector('input[type="text"]')
        pass_input = page.query_selector('input[type="password"]')

        if text_input and pass_input:
            print("Login form found!")
            text_input.fill(username)
            pass_input.fill(password)
            page.wait_for_timeout(1000)

            clicked = False
            for btn in page.query_selector_all("button"):
                btn_text = (btn.inner_text() or "").strip().lower()
                if any(w in btn_text for w in ("login", "sign in", "log in")):
                    print(f"Clicking button: '{btn_text}'")
                    btn.click()
                    clicked = True
                    break
            if not clicked:
                page.keyboard.press("Enter")
                print("Pressed Enter")

            print("Waiting for auth response (up to 90s)...")
            for i in range(90):
                if captured:
                    break
                page.wait_for_timeout(1000)
                if i == 20:
                    print(f"  20s... URL: {page.url}")
                    err = page.query_selector('.error, .alert, [class*=error], [class*=Error]')
                    if err:
                        print(f"  Error on page: {err.inner_text()}")
                if i == 40:
                    print(f"  40s... URL: {page.url}")
                if i == 60:
                    print(f"  60s... URL: {page.url}")
        else:
            print(f"Login form NOT found!")
            print(f"URL: {page.url}")
            print(f"Title: {page.title()}")
            all_inputs = page.query_selector_all("input")
            print(f"Found {len(all_inputs)} input elements")
            for inp in all_inputs:
                print(f"  input type={inp.get_attribute('type')} name={inp.get_attribute('name')}")

        browser.close()

    if captured and "accessToken" in captured:
        print()
        print("=== BROWSER AUTH SUCCESS ===")
        token = captured["accessToken"]
        print(f"Token: {token[:30]}...")
        print(f"userId: {captured.get('userId')}")

        # Save token
        token_data = {
            "access_token": token,
            "md_access_token": captured.get("mdAccessToken", token),
            "expiry": time.time() + 86400,
            "saved_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }
        os.makedirs("configs", exist_ok=True)
        with open("configs/.tradovate_token.json", "w") as f:
            json.dump(token_data, f, indent=2)
        print("Token saved to configs/.tradovate_token.json")
    else:
        print()
        print("=== BROWSER AUTH FAILED ===")
        print("No token was captured")

except Exception as e:
    print(f"Browser auth error: {e}")
    import traceback
    traceback.print_exc()

PYEOF

echo ""

# If token was saved, restart bot
if [ -f "configs/.tradovate_token.json" ]; then
    echo "=== Restarting bot with new token ==="
    # Delete old token that was invalid
    rm -f configs/.tradovate_token.json.bak

    systemctl daemon-reload
    systemctl start futures-bot
    sleep 10

    echo "Service status: $(systemctl is-active futures-bot)"
    echo ""
    echo "Recent log:"
    tail -10 logs/bot.log 2>/dev/null
fi

echo ""
echo "=== END ==="
