#!/bin/bash
# Trigger: v115 - Check bot after auth fix deploy
cd /root/MT5-PropFirm-Bot
echo "=== Status v115 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value 2>/dev/null)"
echo ""
echo "=== Last 25 bot.log ==="
tail -25 logs/bot.log 2>/dev/null || echo "No bot.log"
