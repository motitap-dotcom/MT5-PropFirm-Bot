#!/bin/bash
# Trigger: v147 - Check after renewal fix deploy
cd /root/MT5-PropFirm-Bot
echo "=== v147 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
tail -30 logs/bot.log 2>/dev/null
