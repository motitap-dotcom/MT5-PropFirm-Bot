#!/bin/bash
# Trigger: v136 - Restart bot (new code has Playwright fallback)
cd /root/MT5-PropFirm-Bot

# First ensure latest code
git fetch origin main 2>/dev/null
git reset --hard origin/main 2>/dev/null

# Write .env
source /root/MT5-PropFirm-Bot/.env 2>/dev/null

# Ensure service has PYTHONPATH
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
StartLimitBurst=3
StartLimitIntervalSec=300
Environment=PYTHONUNBUFFERED=1
Environment=PYTHONPATH=/root/MT5-PropFirm-Bot
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl stop futures-bot 2>/dev/null
sleep 2

echo "=== v136 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Starting bot with Playwright auth..."
systemctl start futures-bot

# Don't wait long - bot needs time for Playwright (45s+)
# Just confirm it started
sleep 3
echo "Service: $(systemctl is-active futures-bot)"
echo "Check logs in ~2 min with next status check"
