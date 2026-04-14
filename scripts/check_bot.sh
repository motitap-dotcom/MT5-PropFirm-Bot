#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== Chromium Install Check $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="
echo ""

echo "--- Bot status ---"
echo "State: $(systemctl is-active futures-bot)"
echo "PID:   $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""

echo "--- Chromium binary (BEFORE any action) ---"
ls -la /root/.cache/ms-playwright/chromium-*/chrome-linux/chrome 2>&1 | head -3
find /root/.cache/ms-playwright -maxdepth 2 -type d 2>/dev/null | head -10
echo ""

echo "--- Running: playwright install chromium (download only, no apt) ---"
timeout 300 python3 -m playwright install chromium 2>&1 | tail -30
echo "Exit code: $?"
echo ""

echo "--- Chromium binary (AFTER install) ---"
ls -la /root/.cache/ms-playwright/chromium-*/chrome-linux/chrome 2>&1 | head -3
echo ""

echo "--- Try launching chromium headless ---"
timeout 60 python3 <<'PYEOF' 2>&1
try:
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        page.goto("about:blank", timeout=10000)
        print("LAUNCH OK: chromium loaded about:blank")
        browser.close()
except Exception as e:
    print(f"FAIL: {type(e).__name__}: {e}")
PYEOF
echo ""

echo "--- Bot status (after install, should be untouched) ---"
echo "State: $(systemctl is-active futures-bot)"
echo "PID:   $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "=== END ==="
