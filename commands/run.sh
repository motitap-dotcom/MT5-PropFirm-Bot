#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== $(date -u '+%H:%M UTC')  NY=$(TZ=America/New_York date '+%H:%M') ==="
echo "Service: $(systemctl is-active futures-bot)  Since: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- bot log lines since 15:09 ---"
awk '/2026-04-22 15:09:/,0' logs/bot.log | tail -40
echo ""
echo "--- trend day mentions today ---"
grep -c "Trend day detected" logs/bot.log
echo ""
echo "--- status.json ---"
cat status/status.json
