#!/bin/bash
# Trigger: v138 - Check trading activity
cd /root/MT5-PropFirm-Bot
echo "=== v138 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value 2>/dev/null)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value 2>/dev/null)"
echo ""
echo "=== status.json ==="
cat status/status.json 2>/dev/null || echo "No status.json"
echo ""
echo "=== Last 40 bot.log ==="
tail -40 logs/bot.log 2>/dev/null
