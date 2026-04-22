#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== $(date -u '+%H:%M UTC')  NY=$(TZ=America/New_York date '+%H:%M') ==="
echo "Service: $(systemctl is-active futures-bot)  PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- last 40 bot log lines (live) ---"
tail -40 logs/bot.log 2>/dev/null
echo ""
echo "--- status ---"
cat status/status.json 2>/dev/null
