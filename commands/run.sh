#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== $(date -u '+%H:%M UTC')  NY=$(TZ=America/New_York date '+%H:%M') ==="
echo "Service: $(systemctl is-active futures-bot)  PID: $(systemctl show futures-bot --property=MainPID --value)  Since: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- bot log tail 80 ---"
tail -80 logs/bot.log
echo ""
echo "--- trend day / strategy ---"
grep -c "Trend day" logs/bot.log
grep -c "SHORT SIGNAL\|LONG SIGNAL" logs/bot.log
grep -c "TRADE:" logs/bot.log
echo ""
echo "--- status.json ---"
cat status/status.json
