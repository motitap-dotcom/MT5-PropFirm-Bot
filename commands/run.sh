#!/bin/bash
# Trigger: v195
cd /root/MT5-PropFirm-Bot
echo "=== v195 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
wc -l logs/bot.log 2>/dev/null
echo ""
tail -50 logs/bot.log 2>/dev/null
