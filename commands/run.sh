#!/bin/bash
# Trigger: v157 - check if WebSocket chart data is working
cd /root/MT5-PropFirm-Bot
echo "=== WS CHART CHECK v157 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "Commit: $(git log -1 --oneline)"
echo ""
echo "--- Last 50 log lines ---"
tail -50 logs/bot.log 2>/dev/null
