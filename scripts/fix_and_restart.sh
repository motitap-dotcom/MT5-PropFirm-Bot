#!/bin/bash
# Trigger: bulletproof-exec 2026-04-17
echo "=== Fix & Restart ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot

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

# Service with bulletproof ExecStart (bash -c guarantees PYTHONPATH + cwd)
cat > /etc/systemd/system/futures-bot.service << 'SVCEOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=/bin/bash -c 'cd /root/MT5-PropFirm-Bot && PYTHONPATH=/root/MT5-PropFirm-Bot PYTHONUNBUFFERED=1 /usr/bin/python3 -m futures_bot.bot'
Restart=on-failure
RestartSec=60
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null
systemctl restart futures-bot
sleep 10
echo "Status: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- journalctl last 15 ---"
journalctl -u futures-bot -n 15 --no-pager 2>&1 | tail -15
echo ""
echo "--- bot.log tail ---"
tail -15 /root/MT5-PropFirm-Bot/logs/bot.log 2>/dev/null || echo "no log"
