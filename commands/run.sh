#!/bin/bash
# Trigger: v96 - Quick: run browser auth in background, report status
cd /root/MT5-PropFirm-Bot

echo "=== STATUS + BROWSER AUTH ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

PY="python3"
[ -d "venv" ] && PY="venv/bin/python3"

# Stop bot to avoid interfering
systemctl stop futures-bot 2>/dev/null
echo "Bot stopped"

# Check if browser auth already ran successfully
if [ -f "configs/.tradovate_token.json" ]; then
    echo ""
    echo "=== Existing token file ==="
    cat configs/.tradovate_token.json
fi

echo ""
echo "=== Starting browser auth ==="

# Run browser auth with timeout
timeout 120 $PY -c "
import json, time, os

username = os.environ.get('TRADOVATE_USER', '')
password = os.environ.get('TRADOVATE_PASS', '')

try:
    from playwright.sync_api import sync_playwright
    print('Playwright OK')
except ImportError:
    print('Playwright not available')
    exit(1)

captured = {}
def on_response(response):
    if captured:
        return
    try:
        ct = response.headers.get('content-type', '')
        if 'json' not in ct: return
        data = response.json()
        if isinstance(data, dict) and 'accessToken' in data:
            captured.update(data)
            print(f'TOKEN CAPTURED! userId={data.get(\"userId\")}')
    except: pass

print('Launching Chromium...')
with sync_playwright() as pw:
    browser = pw.chromium.launch(headless=True, args=['--no-sandbox','--disable-dev-shm-usage','--disable-gpu'])
    ctx = browser.new_context(
        viewport={'width':1280,'height':720},
        user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/121.0.0.0 Safari/537.36',
        ignore_https_errors=True)
    ctx.add_init_script(\"Object.defineProperty(navigator,'webdriver',{get:()=>undefined});\")
    page = ctx.new_page()
    page.on('response', on_response)

    print('Loading trader.tradovate.com...')
    page.goto('https://trader.tradovate.com', timeout=60000, wait_until='domcontentloaded')
    print(f'Title: {page.title()}')
    page.wait_for_timeout(10000)

    ti = page.query_selector('input[type=\"text\"]')
    pi = page.query_selector('input[type=\"password\"]')
    if ti and pi:
        print('Filling login form...')
        ti.fill(username)
        pi.fill(password)
        page.wait_for_timeout(500)
        clicked = False
        for btn in page.query_selector_all('button'):
            t = (btn.inner_text() or '').strip().lower()
            if any(w in t for w in ('login','sign in','log in')):
                btn.click(); clicked = True; break
        if not clicked:
            page.keyboard.press('Enter')
        print('Waiting for token (up to 60s)...')
        for i in range(60):
            if captured: break
            page.wait_for_timeout(1000)
            if i == 15: print(f'  15s... URL: {page.url}')
            if i == 30:
                err = page.query_selector('.error,[class*=error],[class*=Error]')
                if err: print(f'  Page error: {err.inner_text()[:200]}')
    else:
        print(f'No login form. Inputs: {len(page.query_selector_all(\"input\"))}')

    browser.close()

if captured and 'accessToken' in captured:
    print('SUCCESS!')
    td = {'access_token':captured['accessToken'],
          'md_access_token':captured.get('mdAccessToken',captured['accessToken']),
          'expiry':time.time()+86400,
          'saved_at':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())}
    os.makedirs('configs',exist_ok=True)
    with open('configs/.tradovate_token.json','w') as f:
        json.dump(td,f,indent=2)
    print('Token saved!')
else:
    print('FAILED - no token captured')
" 2>&1

RESULT=$?
echo ""
echo "Browser auth exit code: $RESULT"

if [ -f "configs/.tradovate_token.json" ]; then
    echo ""
    echo "=== Token file after auth ==="
    cat configs/.tradovate_token.json
    echo ""
    echo "=== Restarting bot ==="
    systemctl start futures-bot
    sleep 8
    echo "Service: $(systemctl is-active futures-bot)"
    tail -10 logs/bot.log 2>/dev/null
fi

echo ""
echo "=== END ==="
