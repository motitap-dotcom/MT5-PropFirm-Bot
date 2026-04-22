#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== $(date -u '+%H:%M UTC')  NY=$(TZ=America/New_York date '+%H:%M') ==="
echo "Service: $(systemctl is-active futures-bot)  Since: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- bot log last 50 ---"
tail -50 logs/bot.log
echo ""
echo "--- active_strategy / status ---"
cat status/status.json
