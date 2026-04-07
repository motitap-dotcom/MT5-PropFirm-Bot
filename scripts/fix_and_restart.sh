#!/bin/bash
echo "=== Fix & Restart ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot

# Ensure PYTHONPATH in service
cat > /etc/systemd/system/futures-bot.service << 'SVCEOF'
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
Environment=PYTHONPATH=/root/MT5-PropFirm-Bot
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl restart futures-bot
echo "Restarted"
sleep 5
echo "Status: $(systemctl is-active futures-bot)"
