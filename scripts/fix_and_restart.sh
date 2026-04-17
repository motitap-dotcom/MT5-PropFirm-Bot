#!/bin/bash
# Trigger: fix-pythonpath 2026-04-17
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
sleep 3
echo "Status: $(systemctl is-active futures-bot)"
