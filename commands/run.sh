#!/bin/bash
# Trigger: v149-status-after-fix
cd /root/MT5-PropFirm-Bot
echo "=== v149 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Code: $(git log -1 --oneline)"
echo ""
echo "--- Last 50 lines of log ---"
tail -50 logs/bot.log 2>/dev/null || echo "No log file"
echo ""
echo "--- Positions ---"
cat status/status.json 2>/dev/null || echo "No status.json"
echo ""
echo "--- Process ---"
ps aux | grep "[f]utures_bot" | head -3
echo "=== END ==="
