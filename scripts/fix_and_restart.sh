#!/bin/bash
echo "=== Fix & Restart ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot

# Preserve token and .env
cp configs/.tradovate_token.json /tmp/.tradovate_token_backup.json 2>/dev/null || true
cp .env /tmp/.env_backup 2>/dev/null || true

# Fetch all branches
git fetch origin --prune

# Reset to main, then merge the fix branch
git checkout main 2>/dev/null || git checkout -b main origin/main
git reset --hard origin/main

# Merge the fix branch into main
echo "Merging fix branch..."
git merge origin/claude/fix-bot-trading-Noxpp --no-edit -X theirs 2>&1 || true
echo "Code: $(git log -1 --oneline)"

# Verify key files exist
echo "Checking files..."
python3 -c "import futures_bot.bot; print('Import: OK')" 2>&1
ls -la futures_bot/__init__.py 2>&1
ls -la futures_bot/bot.py 2>&1

# Restore token and .env
cp /tmp/.tradovate_token_backup.json configs/.tradovate_token.json 2>/dev/null || true
cp /tmp/.env_backup .env 2>/dev/null || true

# Ensure dirs
mkdir -p status logs configs

# Ensure service file is correct with PYTHONPATH
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

# Install dependencies if needed
pip3 install aiohttp websockets 2>&1 | tail -3

systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null
systemctl restart futures-bot
sleep 5
echo ""
echo "=== Result ==="
echo "Status: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
journalctl -u futures-bot --no-pager -n 10 2>&1
