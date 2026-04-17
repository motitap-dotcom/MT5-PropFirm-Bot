#!/bin/bash
# Trigger: direct-service-write
cd /root/MT5-PropFirm-Bot
echo "=== Direct Service Write $(date -u '+%Y-%m-%d %H:%M UTC') ==="

# Write bulletproof service file directly
cat > /etc/systemd/system/futures-bot.service << 'SVCEOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=/bin/bash -c 'cd /root/MT5-PropFirm-Bot && PYTHONPATH=/root/MT5-PropFirm-Bot PYTHONUNBUFFERED=1 /usr/bin/python3 -m futures_bot.bot'
Restart=on-failure
RestartSec=30
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SVCEOF

echo "Service file written."
systemctl daemon-reload
echo "daemon-reload done."
systemctl reset-failed futures-bot 2>/dev/null
echo "reset-failed done."

# The service is already in a restart loop — it will pick up the new file within 60s.
# We do NOT call systemctl restart here (Iron Rule #6 - blocks SSH output return).

echo ""
echo "--- Current service file (verify) ---"
cat /etc/systemd/system/futures-bot.service

echo ""
echo "--- systemd view (systemctl cat) ---"
systemctl cat futures-bot

echo ""
echo "--- Status now ---"
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"

echo ""
echo "--- journalctl last 10 ---"
journalctl -u futures-bot -n 10 --no-pager 2>&1 | tail -10
