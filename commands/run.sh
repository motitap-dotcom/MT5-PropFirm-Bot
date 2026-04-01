#!/bin/bash
# Trigger: v113 - Check Playwright + run browser auth
cd /root/MT5-PropFirm-Bot
source .env 2>/dev/null
echo "=== BROWSER AUTH v113 ==="
date -u
echo ""

# Check Playwright
echo "=== Playwright check ==="
/usr/bin/python3 -c "from playwright.sync_api import sync_playwright; print('Playwright: OK')" 2>&1
echo ""

# Install if missing
if ! /usr/bin/python3 -c "import playwright" 2>/dev/null; then
    echo "Installing Playwright..."
    pip3 install playwright 2>&1 | tail -3
    python3 -m playwright install chromium --with-deps 2>&1 | tail -3
fi

# Stop bot so we don't interfere
systemctl stop futures-bot 2>/dev/null

# Run browser auth
echo "=== Running browser auth ==="
timeout 90 /usr/bin/python3 << 'PYEOF'
import json, time, os

username = os.environ.get('TRADOVATE_USER', '')
password = os.environ.get('TRADOVATE_PASS', '')
print(f"User: {username}, Pass length: {len(password)}")

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("ERROR: Playwright not available")
    exit(1)

captured = {}
def on_response(response):
    if captured: return
    try:
        ct = response.headers.get('content-type', '')
        if 'json' not in ct: return
        data = response.json()
        if isinstance(data, dict) and 'accessToken' in data:
            captured.update(data)
            print(f"TOKEN CAPTURED! userId={data.get('userId')}")
    except: pass

print("Launching Chromium...")
with sync_playwright() as pw:
    browser = pw.chromium.launch(headless=True, args=['--no-sandbox','--disable-dev-shm-usage'])
    ctx = browser.new_context(viewport={'width':1280,'height':720},
        user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/121.0.0.0 Safari/537.36')
    ctx.add_init_script("Object.defineProperty(navigator,'webdriver',{get:()=>undefined});")
    page = ctx.new_page()
    page.on('response', on_response)
    print("Loading trader.tradovate.com...")
    page.goto('https://trader.tradovate.com', timeout=60000, wait_until='domcontentloaded')
    print(f"Page: {page.title()}")
    page.wait_for_timeout(10000)
    ti = page.query_selector('input[type="text"]')
    pi = page.query_selector('input[type="password"]')
    if ti and pi:
        print("Form found, logging in...")
        ti.fill(username)
        pi.fill(password)
        page.wait_for_timeout(500)
        for btn in page.query_selector_all('button'):
            t = (btn.inner_text() or '').strip().lower()
            if any(w in t for w in ('login','sign in','log in')):
                btn.click(); print(f"Clicked: {t}"); break
        else:
            page.keyboard.press('Enter'); print("Pressed Enter")
        print("Waiting for token (up to 60s)...")
        for i in range(60):
            if captured: break
            page.wait_for_timeout(1000)
            if i == 20: print(f"  20s... URL: {page.url}")
            if i == 40: print(f"  40s... URL: {page.url}")
    else:
        print(f"No form! URL: {page.url}, inputs: {len(page.query_selector_all('input'))}")
    browser.close()

if captured and 'accessToken' in captured:
    print("SUCCESS!")
    td = {'access_token':captured['accessToken'],
          'md_access_token':captured.get('mdAccessToken',captured['accessToken']),
          'expiry':time.time()+86400,
          'saved_at':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())}
    with open('configs/.tradovate_token.json','w') as f:
        json.dump(td,f,indent=2)
    print("Token saved!")
else:
    print("FAILED - no token captured")
PYEOF

echo ""
echo "=== Result ==="
cat configs/.tradovate_token.json 2>/dev/null | head -3
echo ""

# Restart bot
systemctl reset-failed futures-bot 2>/dev/null
systemctl start futures-bot
echo "Bot restarted"
sleep 10
echo "Service: $(systemctl is-active futures-bot)"
tail -10 logs/bot.log 2>/dev/null
echo "=== END ==="
