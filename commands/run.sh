#!/bin/bash
# Trigger: post-deploy-check-v1
cd /root/MT5-PropFirm-Bot

echo "=== Post-Deploy Status Check ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "ET Time: $(TZ='America/New_York' date '+%H:%M %Z')"
echo ""

echo "=== Service Status ==="
systemctl status futures-bot --no-pager 2>&1 | head -15
echo ""

echo "=== Venv Check ==="
ls -la venv/bin/python 2>/dev/null || echo "No venv found"
venv/bin/python -c "import futures_bot; print('Import: OK')" 2>&1
venv/bin/python -c "import aiohttp; print('aiohttp: OK')" 2>&1
venv/bin/python -c "import websockets; print('websockets: OK')" 2>&1
venv/bin/python -c "from playwright.async_api import async_playwright; print('playwright: OK')" 2>&1
echo ""

echo "=== Token File ==="
if [ -f configs/.tradovate_token.json ]; then
    echo "Token file exists"
    python3 -c "
import json, time
d = json.loads(open('configs/.tradovate_token.json').read())
exp = d.get('expiry', 0)
remaining = exp - time.time()
print(f'Saved at: {d.get(\"saved_at\", \"unknown\")}')
print(f'Remaining: {remaining/60:.0f} minutes')
" 2>/dev/null || echo "Cannot read token"
else
    echo "No token file"
fi
echo ""

echo "=== .env Check ==="
if [ -f .env ]; then
    echo ".env exists"
    echo "TRADOVATE lines: $(grep -c 'TRADOVATE' .env)"
    echo "TELEGRAM lines: $(grep -c 'TELEGRAM' .env)"
else
    echo ".env NOT FOUND"
fi
echo ""

echo "=== Last 30 Journal Lines ==="
journalctl -u futures-bot --no-pager -n 30 2>&1
echo ""

echo "=== DONE ==="
