#!/bin/bash
# Trigger: v177
cd /root/MT5-PropFirm-Bot
echo "=== v177 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "--- Live bars from today ---"
grep "2026-04-10.*New bar" logs/bot.log 2>/dev/null | tail -10
echo ""
echo "--- VWAP values from today ---"
grep "2026-04-10.*dist=" logs/bot.log 2>/dev/null | tail -10
echo ""
echo "--- Signals from today (live) ---"
grep "2026-04-10.*SIGNAL" logs/bot.log 2>/dev/null | tail -10
echo ""
echo "--- Orders/Trades ---"
grep -i -E "order|placed|fill|execute_trade" logs/bot.log 2>/dev/null | grep "2026-04-10" | tail -10
echo ""
echo "--- Last 15 log ---"
tail -15 logs/bot.log 2>/dev/null
