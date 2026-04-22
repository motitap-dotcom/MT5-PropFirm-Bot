#!/bin/bash
# Trigger: check-service-state
cd /root/MT5-PropFirm-Bot
echo "=== Service state $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
echo ""
echo "=== systemctl status ==="
systemctl status futures-bot --no-pager -n 30 2>&1 | head -60
echo ""
echo "=== journalctl last 80 lines ==="
journalctl -u futures-bot --no-pager -n 80 2>&1 | tail -80
echo ""
echo "=== last 60 log lines ==="
tail -60 logs/bot.log 2>/dev/null || echo "no log"
echo ""
echo "=== status.json ==="
cat status/status.json 2>/dev/null | head -30
echo ""
echo "=== positions via service ==="
# any fills today? any open positions file?
ls -la logs/ status/ 2>&1 | head -20
