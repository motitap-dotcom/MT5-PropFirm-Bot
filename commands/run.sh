#!/bin/bash
# Trigger: v95 - Start bot with fresh token
cd /root/MT5-PropFirm-Bot

echo "=== PYTHON BOT FIX v93 - $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="

# Step 1: Write .env
echo "--- Step 1: Writing .env ---"
if [ -n "$TRADOVATE_USER" ]; then
    echo "TRADOVATE_USER=$TRADOVATE_USER" > .env
    echo "TRADOVATE_PASS=$TRADOVATE_PASS" >> .env
    echo "TRADOVATE_ACCESS_TOKEN=$TRADOVATE_ACCESS_TOKEN" >> .env
    echo "TELEGRAM_TOKEN=$TELEGRAM_TOKEN" >> .env
    echo "TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID" >> .env
    echo ".env written OK"
else
    echo "ERROR: No secrets from workflow!"
fi

# Step 2: Fix pip install (Python 3.12+ needs --break-system-packages or venv)
echo ""
echo "--- Step 2: Installing dependencies ---"
python3 --version

# Try venv first, fallback to --break-system-packages
if [ ! -d "/root/MT5-PropFirm-Bot/venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv /root/MT5-PropFirm-Bot/venv 2>/dev/null || true
fi

if [ -f "/root/MT5-PropFirm-Bot/venv/bin/pip" ]; then
    echo "Using venv pip..."
    /root/MT5-PropFirm-Bot/venv/bin/pip install -r requirements.txt 2>&1 | tail -10
    PYTHON_BIN="/root/MT5-PropFirm-Bot/venv/bin/python3"
else
    echo "No venv, using --break-system-packages..."
    pip3 install --break-system-packages -r requirements.txt 2>&1 | tail -10
    PYTHON_BIN="/usr/bin/python3"
fi

# Step 3: Verify imports
echo ""
echo "--- Step 3: Import check ---"
$PYTHON_BIN -c "
import sys
sys.path.insert(0, '/root/MT5-PropFirm-Bot')
from futures_bot.core.tradovate_client import TradovateClient
from futures_bot.core.guardian import Guardian
print('All imports OK')
" 2>&1

# Step 4: Update systemd service to use venv if available
echo ""
echo "--- Step 4: Updating service ---"
cat > /etc/systemd/system/futures-bot.service << SERVICEEOF
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=${PYTHON_BIN} -m futures_bot.bot
Restart=on-failure
RestartSec=30
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SERVICEEOF

mkdir -p logs status

# Step 5: Test Tradovate auth
echo ""
echo "--- Step 5: Testing Tradovate auth ---"
$PYTHON_BIN -c "
import sys, os, asyncio
sys.path.insert(0, '/root/MT5-PropFirm-Bot')

# Load .env
with open('.env') as f:
    for line in f:
        if '=' in line:
            k, v = line.strip().split('=', 1)
            os.environ[k] = v

from futures_bot.core.tradovate_client import TradovateClient

async def test():
    c = TradovateClient(
        username=os.environ.get('TRADOVATE_USER', ''),
        password=os.environ.get('TRADOVATE_PASS', ''),
        live=False,
        organization='TradeDay',
    )
    try:
        await c.connect()
        print(f'CONNECTED! Account: {c.account_spec} ID: {c.account_id}')
        bal = await c.get_account_balance()
        print(f'Balance: \${bal.get(\"balance\", 0):.2f}')
        await c.disconnect()
    except Exception as e:
        print(f'AUTH FAILED: {e}')
        if 'CAPTCHA' in str(e):
            print('')
            print('*** CAPTCHA REQUIRED ***')
            print('Set a fresh TRADOVATE_ACCESS_TOKEN in GitHub Secrets')

asyncio.run(test())
" 2>&1

# Step 6: Restart bot
echo ""
echo "--- Step 6: Restarting bot ---"
systemctl stop futures-bot 2>/dev/null
systemctl daemon-reload
systemctl start futures-bot
sleep 10

echo "Service: $(systemctl is-active futures-bot)"
journalctl -u futures-bot --no-pager -n 15 --since "15 sec ago" 2>&1
echo ""
tail -15 logs/bot.log 2>/dev/null || echo "No bot.log yet"

echo ""
echo "=== FIX COMPLETE ==="
