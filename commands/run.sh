#!/bin/bash
# Trigger: v126 - Final status check
cd /root/MT5-PropFirm-Bot
echo "=== FINAL STATUS v126 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value 2>/dev/null)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value 2>/dev/null)"
echo ""
echo "=== Last 30 bot.log ==="
tail -30 logs/bot.log 2>/dev/null || echo "No bot.log"
