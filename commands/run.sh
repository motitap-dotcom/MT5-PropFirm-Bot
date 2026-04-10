#!/bin/bash
# Trigger: v176
cd /root/MT5-PropFirm-Bot
echo "=== v176 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo ""
tail -30 logs/bot.log 2>/dev/null
echo ""
echo "--- Signals + Trades today ---"
grep -i -E "SIGNAL|order|placed|fill|execute|LONG|SHORT|dist=" logs/bot.log 2>/dev/null | grep "2026-04-10" | tail -15
