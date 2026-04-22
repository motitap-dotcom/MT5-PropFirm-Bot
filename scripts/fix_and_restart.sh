#!/bin/bash
# v154 - fix path + restart
echo "=== Fix & Restart v154 ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot

echo ""
echo "--- BEFORE: current service config ---"
systemctl cat futures-bot 2>/dev/null | grep -E "ExecStart|WorkingDir" || echo "no service"

echo ""
echo "--- BEFORE: running processes ---"
ps -ef | grep -E "futures_bot|bot\.py" | grep -v grep | head -5

# Preserve token
cp configs/.tradovate_token.json /tmp/.tradovate_token_backup.json 2>/dev/null || true

# Pull latest from main
git fetch origin main
git reset --hard origin/main
echo "Code: $(git log -1 --oneline)"

# Restore token
cp /tmp/.tradovate_token_backup.json configs/.tradovate_token.json 2>/dev/null || true

# Ensure dirs
mkdir -p status logs

# Stop service first to release any stale /opt/ binaries
systemctl stop futures-bot 2>/dev/null || true
sleep 2

# Kill any stragglers from /opt/futures_bot_stable
pkill -9 -f "/opt/futures_bot_stable" 2>/dev/null || true
pkill -9 -f "futures-bot-wrapper" 2>/dev/null || true
sleep 1

# Write CORRECT service file: runs from /root/MT5-PropFirm-Bot
cat > /etc/systemd/system/futures-bot.service << 'SVCEOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=/usr/bin/python3 -m futures_bot.bot
Restart=on-failure
RestartSec=60
Environment=PYTHONUNBUFFERED=1
Environment=PYTHONPATH=/root/MT5-PropFirm-Bot
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null
systemctl enable futures-bot 2>/dev/null
systemctl start futures-bot

sleep 5

echo ""
echo "--- AFTER: service config ---"
systemctl cat futures-bot 2>/dev/null | grep -E "ExecStart|WorkingDir"

echo ""
echo "--- AFTER: status ---"
echo "Active: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Since: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"

echo ""
echo "--- AFTER: running process ---"
ps -ef | grep -E "futures_bot|bot\.py" | grep -v grep | head -3

echo ""
echo "--- Recent bot log ---"
tail -25 logs/bot.log 2>/dev/null

echo ""
echo "=== Done at $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="
