#!/bin/bash
# Trigger: v187
cd /root/MT5-PropFirm-Bot
echo "=== v187 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "Commit: $(git log -1 --oneline)"
echo ""
echo "--- WS disconnects count (last hour) ---"
grep -c "WebSocket disconnected" logs/bot.log 2>/dev/null
echo ""
echo "--- Last 30 ---"
tail -30 logs/bot.log 2>/dev/null
