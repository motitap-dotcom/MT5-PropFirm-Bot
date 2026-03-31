#!/bin/bash
# Trigger: v97 - Launch browser auth in background, return fast
cd /root/MT5-PropFirm-Bot

echo "=== LAUNCH BROWSER AUTH ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

PY="python3"
[ -d "venv" ] && PY="venv/bin/python3"

# Stop bot
systemctl stop futures-bot 2>/dev/null
echo "Bot stopped"

# Write the browser auth script to a temp file
cat > /tmp/browser_auth.py << 'AUTHEOF'
import json, time, os, sys

username = os.environ.get('TRADOVATE_USER', '')
password = os.environ.get('TRADOVATE_PASS', '')
result_file = "/root/MT5-PropFirm-Bot/configs/.browser_auth_result.txt"

def log(msg):
    with open(result_file, "a") as f:
        f.write(f"{time.strftime('%H:%M:%S')} {msg}\n")
    print(msg)

log(f"Starting browser auth for {username}")

try:
    from playwright.sync_api import sync_playwright
    log("Playwright loaded")
except ImportError:
    log("ERROR: Playwright not available")
    sys.exit(1)

captured = {}
def on_response(response):
    if captured: return
    try:
        ct = response.headers.get('content-type', '')
        if 'json' not in ct: return
        data = response.json()
        if isinstance(data, dict) and 'accessToken' in data:
            captured.update(data)
            log(f"TOKEN CAPTURED! userId={data.get('userId')}")
    except: pass

log("Launching Chromium...")
try:
    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=True, args=['--no-sandbox','--disable-dev-shm-usage','--disable-gpu'])
        ctx = browser.new_context(
            viewport={'width':1280,'height':720},
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/121.0.0.0 Safari/537.36',
            ignore_https_errors=True)
        ctx.add_init_script("Object.defineProperty(navigator,'webdriver',{get:()=>undefined});")
        page = ctx.new_page()
        page.on('response', on_response)

        log("Loading trader.tradovate.com...")
        page.goto('https://trader.tradovate.com', timeout=60000, wait_until='domcontentloaded')
        log(f"Title: {page.title()}")
        page.wait_for_timeout(10000)

        ti = page.query_selector('input[type="text"]')
        pi = page.query_selector('input[type="password"]')
        if ti and pi:
            log("Login form found, filling...")
            ti.fill(username)
            pi.fill(password)
            page.wait_for_timeout(500)
            for btn in page.query_selector_all('button'):
                t = (btn.inner_text() or '').strip().lower()
                if any(w in t for w in ('login','sign in','log in')):
                    btn.click()
                    log(f"Clicked: {t}")
                    break
            else:
                page.keyboard.press('Enter')
                log("Pressed Enter")

            log("Waiting for token...")
            for i in range(90):
                if captured: break
                page.wait_for_timeout(1000)
                if i == 15: log(f"  15s... URL: {page.url}")
                if i == 30:
                    err = page.query_selector('.error,[class*=error],[class*=Error]')
                    if err: log(f"  Error: {err.inner_text()[:200]}")
                    log(f"  30s... URL: {page.url}")
                if i == 60: log(f"  60s... URL: {page.url}")
        else:
            log(f"No login form. URL: {page.url}")
            inputs = page.query_selector_all("input")
            log(f"Found {len(inputs)} inputs")
            for inp in inputs:
                log(f"  type={inp.get_attribute('type')} name={inp.get_attribute('name')}")

        browser.close()

    if captured and 'accessToken' in captured:
        log("=== SUCCESS ===")
        td = {'access_token':captured['accessToken'],
              'md_access_token':captured.get('mdAccessToken',captured['accessToken']),
              'expiry':time.time()+86400,
              'saved_at':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())}
        os.makedirs('/root/MT5-PropFirm-Bot/configs', exist_ok=True)
        with open('/root/MT5-PropFirm-Bot/configs/.tradovate_token.json','w') as f:
            json.dump(td,f,indent=2)
        log("Token saved!")
        # Restart bot
        os.system("systemctl start futures-bot")
        log("Bot restarted")
    else:
        log("=== FAILED - no token captured ===")

except Exception as e:
    log(f"ERROR: {e}")
    import traceback
    traceback.print_exc()
AUTHEOF

# Clear previous result
rm -f configs/.browser_auth_result.txt

# Export env vars and run in background
export TRADOVATE_USER TRADOVATE_PASS
nohup $PY /tmp/browser_auth.py > /tmp/browser_auth.log 2>&1 &
AUTH_PID=$!
echo "Browser auth launched in background (PID: $AUTH_PID)"
echo ""

# Wait a few seconds to see if it crashes immediately
sleep 5
if kill -0 $AUTH_PID 2>/dev/null; then
    echo "Process still running (good)"
else
    echo "Process exited early. Output:"
    cat /tmp/browser_auth.log 2>/dev/null
fi

echo ""
echo "=== Check results later with: cat configs/.browser_auth_result.txt ==="
echo "=== END ==="
