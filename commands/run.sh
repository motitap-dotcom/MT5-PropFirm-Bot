#!/bin/bash
# Trigger: v123 - Create wrapper + fix service (no git reset)
cd /root/MT5-PropFirm-Bot
echo "=== FIX SERVICE v123 ==="
date -u

echo '#!/bin/bash' > /usr/local/bin/start-futures-bot.sh
echo 'cd /root/MT5-PropFirm-Bot' >> /usr/local/bin/start-futures-bot.sh
echo 'export PYTHONPATH=/root/MT5-PropFirm-Bot' >> /usr/local/bin/start-futures-bot.sh
echo 'exec /usr/bin/python3 -m futures_bot.bot' >> /usr/local/bin/start-futures-bot.sh
chmod +x /usr/local/bin/start-futures-bot.sh
echo "Wrapper created"

echo '[Unit]' > /etc/systemd/system/futures-bot.service
echo 'Description=TradeDay Futures Trading Bot' >> /etc/systemd/system/futures-bot.service
echo 'After=network.target' >> /etc/systemd/system/futures-bot.service
echo '' >> /etc/systemd/system/futures-bot.service
echo '[Service]' >> /etc/systemd/system/futures-bot.service
echo 'Type=simple' >> /etc/systemd/system/futures-bot.service
echo 'ExecStart=/usr/local/bin/start-futures-bot.sh' >> /etc/systemd/system/futures-bot.service
echo 'Restart=on-failure' >> /etc/systemd/system/futures-bot.service
echo 'RestartSec=60' >> /etc/systemd/system/futures-bot.service
echo 'Environment=PYTHONUNBUFFERED=1' >> /etc/systemd/system/futures-bot.service
echo 'EnvironmentFile=/root/MT5-PropFirm-Bot/.env' >> /etc/systemd/system/futures-bot.service
echo '' >> /etc/systemd/system/futures-bot.service
echo '[Install]' >> /etc/systemd/system/futures-bot.service
echo 'WantedBy=multi-user.target' >> /etc/systemd/system/futures-bot.service
echo "Service file created"

systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null
systemctl restart futures-bot
echo "Bot restarted"

sleep 20
echo "Service: $(systemctl is-active futures-bot)"
echo ""
tail -25 logs/bot.log 2>/dev/null || echo "No log"
echo ""
journalctl -u futures-bot --no-pager -n 5 2>&1
echo "=== END ==="
