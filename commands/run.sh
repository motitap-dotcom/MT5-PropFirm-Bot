#!/bin/bash
# Trigger: v171
cd /root/MT5-PropFirm-Bot
echo "=== v171 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- VWAP values (should NOT be 0 now) ---"
grep "dist=" logs/bot.log 2>/dev/null | tail -15
echo ""
echo "--- Signals? ---"
grep -i -E "SIGNAL|LONG|SHORT|order|placed|fill|execute" logs/bot.log 2>/dev/null | tail -10
echo ""
echo "--- Last 15 log lines ---"
tail -15 logs/bot.log 2>/dev/null
