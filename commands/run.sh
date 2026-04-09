#!/bin/bash
# Trigger: v151 - verify bot is running after fix
cd /root/MT5-PropFirm-Bot
echo "=== VERIFY v151 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- Last 20 log lines ---"
tail -20 logs/bot.log 2>/dev/null
echo ""
echo "--- Status JSON ---"
cat status/status.json 2>/dev/null || echo "No status.json"
