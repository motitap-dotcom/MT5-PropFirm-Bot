#!/bin/bash
# Trigger: v175 - post market open
cd /root/MT5-PropFirm-Bot
echo "=== POST OPEN v175 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "--- Last 50 log lines ---"
tail -50 logs/bot.log 2>/dev/null
echo ""
echo "--- Signals + Trades today ---"
grep -i -E "SIGNAL|order|placed|fill|execute|LONG|SHORT|dist=" logs/bot.log 2>/dev/null | grep "2026-04-10" | tail -20
