#!/bin/bash
# Trigger: v146
cd /root/MT5-PropFirm-Bot
echo "=== v146 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
tail -40 logs/bot.log 2>/dev/null
