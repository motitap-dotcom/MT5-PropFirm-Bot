#!/bin/bash
echo "=== Fix & Restart v5 - bash -c approach ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot

# Preserve token and .env
cp configs/.tradovate_token.json /tmp/.tradovate_token_backup.json 2>/dev/null || true
cp .env /tmp/.env_backup 2>/dev/null || true

# Pull latest from main
git fetch origin main
git reset --hard origin/main
echo "Code: $(git log -1 --oneline)"

# Restore token and .env
cp /tmp/.tradovate_token_backup.json configs/.tradovate_token.json 2>/dev/null || true
cp /tmp/.env_backup .env 2>/dev/null || true

# Ensure required directories exist
mkdir -p status logs

# Service file - use bash -c to set PYTHONPATH inline
cat > /etc/systemd/system/futures-bot.service << 'SVCEOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=/bin/bash -c "cd /root/MT5-PropFirm-Bot && export PYTHONPATH=/root/MT5-PropFirm-Bot && exec /usr/bin/python3 -m futures_bot.bot"
Restart=on-failure
RestartSec=30
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null
systemctl restart futures-bot
sleep 5
echo ""
echo "--- Post-Restart ---"
echo "Status: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
journalctl -u futures-bot --no-pager -n 10 --since "10 sec ago" 2>&1
