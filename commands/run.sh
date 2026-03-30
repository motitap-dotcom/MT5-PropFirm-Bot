#!/bin/bash
# Trigger: v57 - Simple status check (no deploy)
cd /root/MT5-PropFirm-Bot
echo "=== TIMESTAMP ==="
date -u
echo ""
echo "=== SERVICE STATUS ==="
systemctl is-active futures-bot
echo ""
echo "=== LAST 50 JOURNAL LINES ==="
journalctl -u futures-bot --no-pager -n 50
echo ""
echo "=== BOT LOG TAIL ==="
tail -20 logs/bot.log 2>/dev/null || echo "No bot.log"
echo ""
echo "=== GIT LOG ==="
git log --oneline -3
echo ""
echo "=== PYTHON CODE VERSION CHECK ==="
head -5 futures_bot/core/tradovate_client.py
echo ""
echo "=== TOKEN FILE ==="
cat configs/.tradovate_token.json 2>/dev/null || echo "No token file"
echo ""
echo "=== PROCESSES ==="
ps aux | grep "futures_bot\|python.*bot" | grep -v grep
