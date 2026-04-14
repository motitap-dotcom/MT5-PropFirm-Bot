#!/bin/bash
# Trigger: install-chromium-for-playwright
cd /root/MT5-PropFirm-Bot
echo "=== Install Chromium for Playwright $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""

echo "--- Before: chromium binary status ---"
ls -la /root/.cache/ms-playwright/chromium-*/chrome-linux/chrome 2>&1 | head -3
echo ""

echo "--- Installing Chromium via Playwright ---"
python3 -m playwright install chromium 2>&1 | tail -20
echo ""

echo "--- Installing system dependencies (if needed) ---"
python3 -m playwright install-deps chromium 2>&1 | tail -10
echo ""

echo "--- After: chromium binary status ---"
ls -la /root/.cache/ms-playwright/chromium-*/chrome-linux/chrome 2>&1 | head -3
echo ""

echo "--- Verify Playwright can launch chromium ---"
python3 -c "
from playwright.sync_api import sync_playwright
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        print('LAUNCH OK')
        browser.close()
        print('CLOSE OK')
except Exception as e:
    print(f'FAIL: {type(e).__name__}: {e}')
" 2>&1
echo ""

echo "--- Bot status (should still be running, untouched) ---"
echo "State: $(systemctl is-active futures-bot)"
echo "PID:   $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "=== END ==="
