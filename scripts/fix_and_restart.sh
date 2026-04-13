#!/bin/bash
echo "=== Fix & Restart v2 ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot

# Preserve token
cp configs/.tradovate_token.json /tmp/.tradovate_token_backup.json 2>/dev/null || true

# Pull latest from main
git fetch origin main
git reset --hard origin/main
echo "Code on main: $(git log -1 --oneline)"

# Restore token
cp /tmp/.tradovate_token_backup.json configs/.tradovate_token.json 2>/dev/null || true

# Ensure dirs
mkdir -p status logs

# DEBUG: Check module importability
echo ""
echo "=== DEBUG: module check ==="
echo "PWD: $(pwd)"
echo "futures_bot/__init__.py: $(ls -la futures_bot/__init__.py 2>&1)"
echo "futures_bot/bot.py: $(ls -la futures_bot/bot.py 2>&1)"
echo "Test import (no PYTHONPATH):"
/usr/bin/python3 -c "import futures_bot.bot; print('OK')" 2>&1 || echo "FAILED without PYTHONPATH"
echo "Test import (with PYTHONPATH):"
PYTHONPATH=/root/MT5-PropFirm-Bot /usr/bin/python3 -c "import futures_bot.bot; print('OK')" 2>&1 || echo "FAILED with PYTHONPATH"
echo ""

# Kill any stray python processes holding old code
echo "=== Killing stray futures_bot processes ==="
pkill -9 -f "futures_bot.bot" 2>/dev/null && echo "Killed stray processes" || echo "No stray processes"

# Service with PYTHONPATH
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

echo "=== Service file written ==="
cat /etc/systemd/system/futures-bot.service

systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null
systemctl restart futures-bot

# Wait longer and verify
sleep 15
echo ""
echo "=== Post-restart status ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "SubState: $(systemctl show futures-bot --property=SubState --value)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Restarts: $(systemctl show futures-bot --property=NRestarts --value)"
echo ""
echo "=== journalctl -u futures-bot -n 30 ==="
journalctl -u futures-bot -n 30 --no-pager
echo ""
echo "=== tail logs/bot.log ==="
tail -30 logs/bot.log 2>/dev/null
