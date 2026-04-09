#!/bin/bash
# Trigger: v162
cd /root/MT5-PropFirm-Bot
echo "=== STATUS v162 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- Last 40 log lines ---"
tail -40 logs/bot.log 2>/dev/null
echo ""
echo "--- Any signals or trades? ---"
grep -i -E "SIGNAL|LONG|SHORT|order|placed|fill|execute|entry" logs/bot.log 2>/dev/null | tail -10
