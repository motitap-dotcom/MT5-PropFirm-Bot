#!/bin/bash
# Trigger: v87 - Full diagnostic + restart with fixes
cd /root/MT5-PropFirm-Bot

echo "=== DIAGNOSTIC v87 - $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="

# Step 1: Write fresh .env from workflow secrets
echo "--- Step 1: Writing .env ---"
if [ -n "$TRADOVATE_USER" ]; then
    echo "TRADOVATE_USER=$TRADOVATE_USER" > .env
    echo "TRADOVATE_PASS=$TRADOVATE_PASS" >> .env
    echo "TRADOVATE_ACCESS_TOKEN=$TRADOVATE_ACCESS_TOKEN" >> .env
    echo "TELEGRAM_TOKEN=$TELEGRAM_TOKEN" >> .env
    echo "TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID" >> .env
    echo ".env written with secrets"
else
    echo "WARNING: No secrets available from workflow!"
fi

# Step 2: Check current state
echo ""
echo "--- Step 2: Current bot state ---"
echo "Service status: $(systemctl is-active futures-bot 2>/dev/null || echo 'not found')"
echo "Bot process: $(pgrep -f 'futures_bot' || echo 'not running')"
echo "Current branch: $(git branch --show-current)"
echo "Last commit: $(git log --oneline -1)"
echo ""

# Step 3: Show existing logs
echo "--- Step 3: Last 30 lines of bot.log ---"
tail -30 logs/bot.log 2>/dev/null || echo "No bot.log found"
echo ""

# Step 4: Check Python and dependencies
echo "--- Step 4: Python environment ---"
python3 --version
pip3 list 2>/dev/null | grep -iE "aiohttp|websockets" || echo "Dependencies not found"
echo ""

# Step 5: Test Tradovate API connectivity
echo "--- Step 5: API connectivity ---"
curl -s -o /dev/null -w "Tradovate Demo API: HTTP %{http_code}\n" https://demo.tradovateapi.com/v1 2>/dev/null
curl -s -o /dev/null -w "Tradovate Live API: HTTP %{http_code}\n" https://live.tradovateapi.com/v1 2>/dev/null
curl -s -o /dev/null -w "Tradovate MD Demo: HTTP %{http_code}\n" https://md-demo.tradovateapi.com/v1 2>/dev/null
curl -s -o /dev/null -w "Telegram API: HTTP %{http_code}\n" https://api.telegram.org 2>/dev/null
echo ""

# Step 6: Stop, pull latest, install deps, restart
echo "--- Step 6: Deploy latest code and restart ---"
systemctl stop futures-bot 2>/dev/null
pkill -f "futures_bot" 2>/dev/null
sleep 2

pip3 install -r requirements.txt 2>&1 | tail -5
echo ""

# Step 7: Verify bot can import
echo "--- Step 7: Import check ---"
python3 -c "
import sys
sys.path.insert(0, '.')
from futures_bot.core.tradovate_client import TradovateClient
from futures_bot.core.guardian import Guardian
from futures_bot.strategies.vwap_mean_reversion import VWAPMeanReversion
from futures_bot.strategies.orb_breakout import ORBBreakout
print('All imports OK')
" 2>&1
echo ""

# Step 8: Check systemd service file
echo "--- Step 8: Service file ---"
if [ -f /etc/systemd/system/futures-bot.service ]; then
    cat /etc/systemd/system/futures-bot.service
else
    echo "Service file not found! Installing..."
    bash scripts/install_bot.sh 2>&1 | tail -10
fi
echo ""

# Step 9: Start bot
echo "--- Step 9: Starting bot ---"
systemctl daemon-reload
systemctl restart futures-bot
sleep 10

echo "Service status after restart: $(systemctl is-active futures-bot)"
echo ""

# Step 10: Capture startup logs
echo "--- Step 10: Startup logs ---"
journalctl -u futures-bot --no-pager -n 30 --since "15 sec ago" 2>&1
echo ""
echo "--- Bot log after restart ---"
tail -30 logs/bot.log 2>/dev/null || echo "No bot.log yet"
echo ""

# Step 11: Show status.json
echo "--- Step 11: status.json ---"
cat status/status.json 2>/dev/null || echo "No status.json"
echo ""

echo "=== DIAGNOSTIC COMPLETE ==="
