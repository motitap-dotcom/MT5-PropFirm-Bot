#!/bin/bash
# Trigger: v91 - Install and start Python futures bot on VPS
cd /root/MT5-PropFirm-Bot

echo "=== PYTHON BOT SETUP v91 - $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="

# Step 1: Write .env from workflow secrets
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

# Step 2: Install dependencies
echo ""
echo "--- Step 2: Installing Python dependencies ---"
python3 --version
pip3 install -r requirements.txt 2>&1 | tail -5

# Step 3: Verify imports
echo ""
echo "--- Step 3: Import check ---"
python3 -c "
import sys
sys.path.insert(0, '.')
from futures_bot.core.tradovate_client import TradovateClient
from futures_bot.core.guardian import Guardian
from futures_bot.strategies.vwap_mean_reversion import VWAPMeanReversion
print('All imports OK')
" 2>&1

# Step 4: Install systemd service
echo ""
echo "--- Step 4: Installing service ---"
cat > /etc/systemd/system/futures-bot.service << 'SERVICEEOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=/usr/bin/python3 -m futures_bot.bot
Restart=on-failure
RestartSec=30
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SERVICEEOF

mkdir -p logs status

# Step 5: Stop any existing bot, start fresh
echo ""
echo "--- Step 5: Starting bot ---"
systemctl stop futures-bot 2>/dev/null
pkill -f "futures_bot" 2>/dev/null
sleep 2
systemctl daemon-reload
systemctl enable futures-bot
systemctl start futures-bot
sleep 10

# Step 6: Check status
echo ""
echo "--- Step 6: Bot status ---"
echo "Service: $(systemctl is-active futures-bot)"
systemctl status futures-bot --no-pager 2>&1 | head -15
echo ""

# Step 7: Show logs
echo "--- Step 7: Bot logs ---"
journalctl -u futures-bot --no-pager -n 30 --since "15 sec ago" 2>&1
echo ""
tail -30 logs/bot.log 2>/dev/null || echo "No bot.log yet"
echo ""

# Step 8: status.json
echo "--- Step 8: status.json ---"
cat status/status.json 2>/dev/null || echo "No status.json yet"

echo ""
echo "=== SETUP COMPLETE ==="
