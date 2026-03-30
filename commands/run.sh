#!/bin/bash
# Trigger: v54 - full trading status check
cd /root/MT5-PropFirm-Bot
echo "=== TIMESTAMP ==="
date -u
echo ""
echo "=== SERVICE STATUS ==="
systemctl is-active futures-bot
systemctl status futures-bot --no-pager -l 2>/dev/null | tail -5
echo ""
echo "=== RECENT LOGS (last 20 min) ==="
journalctl -u futures-bot --no-pager -n 80 --since "20 min ago"
echo ""
echo "=== BOT LOG TAIL ==="
tail -30 logs/bot.log 2>/dev/null || echo "No bot.log found"
echo ""
echo "=== STATUS JSON ==="
cat status/status.json 2>/dev/null || echo "No status.json found"
echo ""
echo "=== ENV FILE EXISTS ==="
test -f .env && echo ".env exists" || echo ".env NOT FOUND"
echo ""
echo "=== PYTHON PROCESS ==="
ps aux | grep -i "bot\|python" | grep -v grep
