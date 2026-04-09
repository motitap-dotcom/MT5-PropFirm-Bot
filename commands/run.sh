#!/bin/bash
# Trigger: v161
cd /root/MT5-PropFirm-Bot
echo "=== CHECK v161 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- Last 60 log lines ---"
tail -60 logs/bot.log 2>/dev/null
