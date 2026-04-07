#!/bin/bash
# Trigger: v144 - Fix service PYTHONPATH + reset-failed + check
cd /root/MT5-PropFirm-Bot
echo "=== v144 $(date -u '+%Y-%m-%d %H:%M UTC') ==="

# Fix service file
sed -i '/Environment=PYTHONUNBUFFERED/a Environment=PYTHONPATH=/root/MT5-PropFirm-Bot' /etc/systemd/system/futures-bot.service 2>/dev/null
grep "PYTHONPATH" /etc/systemd/system/futures-bot.service && echo "PYTHONPATH added" || echo "PYTHONPATH NOT FOUND"

systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null
systemctl stop futures-bot 2>/dev/null
sleep 2
systemctl start futures-bot
sleep 8

echo "Service: $(systemctl is-active futures-bot)"
echo ""
journalctl -u futures-bot --no-pager -n 10 --since "15 sec ago" 2>&1
