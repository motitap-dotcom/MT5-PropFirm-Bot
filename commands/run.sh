#!/bin/bash
# Trigger: v170
cd /root/MT5-PropFirm-Bot
echo "=== v170 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- VWAP values + signals ---"
grep -E "Price=|SIGNAL|LONG|SHORT|order|placed|fill|execute|dist=" logs/bot.log 2>/dev/null | tail -30
echo ""
echo "--- Last 20 log lines ---"
tail -20 logs/bot.log 2>/dev/null
