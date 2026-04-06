#!/bin/bash
# Trigger: v100 - Fix PYTHONPATH in service + write .env + restart
cd /root/MT5-PropFirm-Bot

echo "=== Fix v100 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"

# Fix service file with PYTHONPATH
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

# Write .env
if [ -n "${TRADOVATE_USER}" ]; then
    cat > .env << ENVEOF
TRADOVATE_USER=${TRADOVATE_USER}
TRADOVATE_PASS=${TRADOVATE_PASS}
TRADOVATE_ACCESS_TOKEN=${TRADOVATE_ACCESS_TOKEN}
TELEGRAM_TOKEN=${TELEGRAM_TOKEN}
TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
ENVEOF
    echo ".env written"
fi

# Restart
systemctl daemon-reload
systemctl stop futures-bot 2>/dev/null
sleep 2
systemctl start futures-bot
sleep 15

echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "=== Logs ==="
journalctl -u futures-bot --no-pager -n 20 2>&1
echo ""
echo "=== Bot log ==="
tail -15 logs/bot.log 2>/dev/null || echo "No bot.log"
