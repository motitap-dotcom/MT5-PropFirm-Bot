#!/bin/bash
# Trigger: v163
cd /root/MT5-PropFirm-Bot
echo "=== CHECK v163 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- Last 50 log lines ---"
tail -50 logs/bot.log 2>/dev/null
echo ""
echo "--- Signals/Trades ---"
grep -i -E "SIGNAL|LONG|SHORT|order|placed|fill|execute|entry" logs/bot.log 2>/dev/null | tail -10
