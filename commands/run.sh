#!/bin/bash
# Trigger: v157-final
cd /root/MT5-PropFirm-Bot
echo "=== v157 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(ps -o etime= -p $(systemctl show futures-bot --property=MainPID --value) 2>/dev/null || echo 'N/A')"
echo "Code: $(git log -1 --oneline)"
echo ""
echo "--- Bot Log (last 80) ---"
tail -80 logs/bot.log 2>/dev/null | grep -v "^$"
echo ""
echo "--- Status JSON ---"
cat status/status.json 2>/dev/null || echo "No status.json"
echo "=== END ==="
