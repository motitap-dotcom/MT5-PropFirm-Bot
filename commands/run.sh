#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== $(date -u '+%H:%M UTC')  NY=$(TZ=America/New_York date '+%H:%M') ==="
PID=$(systemctl show futures-bot --property=MainPID --value)
echo "Service: $(systemctl is-active futures-bot)  PID: $PID  Since: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- bot log tail 35 ---"
tail -35 logs/bot.log
echo ""
echo "--- status.json ---"
cat status/status.json
