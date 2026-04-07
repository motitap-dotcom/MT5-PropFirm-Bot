#!/bin/bash
echo "=== Fix & Restart v4 - FINAL ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot

# Code is already updated by the workflow (git reset --hard)
echo "Code: $(git log -1 --oneline)"

# Preserve token
cp configs/.tradovate_token.json /tmp/.tradovate_token_backup.json 2>/dev/null || true

# Restore token (in case git reset deleted it)
cp /tmp/.tradovate_token_backup.json configs/.tradovate_token.json 2>/dev/null || true

# Ensure directories exist
mkdir -p status logs configs

# Verify code is correct
echo "--- Verify ---"
python3 -c "import futures_bot.bot; print('Import: OK')" 2>&1
ls futures_bot/__init__.py futures_bot/bot.py futures_bot/core/tradovate_client.py 2>&1

# Install dependencies
echo "--- Dependencies ---"
pip3 install aiohttp websockets 2>&1 | tail -5

# Ensure correct service file
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

# Restart service
systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null
systemctl restart futures-bot

# Wait and check
sleep 5
echo ""
echo "=== Result ==="
echo "Status: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
tail -15 logs/bot.log 2>/dev/null || echo "No log yet"
