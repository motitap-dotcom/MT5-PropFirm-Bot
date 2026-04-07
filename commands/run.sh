#!/bin/bash
# Trigger: v148
cd /root/MT5-PropFirm-Bot
echo "=== v148 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Code: $(git log -1 --oneline)"
echo ""
tail -30 logs/bot.log 2>/dev/null
