#!/bin/bash
echo "=== Fix & Restart v3 - Full Fix ==="
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

# Verify critical files
echo ""
echo "--- File Checks ---"
echo "configs/bot_config.json: $(ls -la configs/bot_config.json 2>/dev/null && echo OK || echo MISSING)"
echo "configs/restricted_events.json: $(ls -la configs/restricted_events.json 2>/dev/null && echo OK || echo MISSING)"
echo "status/ dir: $(ls -d status/ 2>/dev/null && echo OK || echo MISSING)"
echo ".env: $(ls -la .env 2>/dev/null && echo OK || echo MISSING)"
echo "token: $(ls -la configs/.tradovate_token.json 2>/dev/null && echo OK || echo MISSING)"

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

systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null
systemctl restart futures-bot
sleep 5
echo ""
echo "--- Post-Restart Status ---"
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
journalctl -u futures-bot --no-pager -n 10 --since "10 sec ago" 2>&1
