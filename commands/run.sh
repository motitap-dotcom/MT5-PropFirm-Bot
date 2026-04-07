#!/bin/bash
# Trigger: v139 - Check trading signals after market open
cd /root/MT5-PropFirm-Bot
echo "=== v139 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value 2>/dev/null)"
echo ""
echo "=== status.json ==="
cat status/status.json 2>/dev/null || echo "No status.json"
echo ""
echo "=== Last 50 bot.log ==="
tail -50 logs/bot.log 2>/dev/null
