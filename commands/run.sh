#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== $(date -u '+%H:%M UTC')  NY=$(TZ=America/New_York date '+%H:%M') ==="
echo "Service: $(systemctl is-active futures-bot)  PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Since: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- last 50 bot log ---"
tail -50 logs/bot.log
echo ""
echo "--- positions ---"
cat status/status.json 2>/dev/null
