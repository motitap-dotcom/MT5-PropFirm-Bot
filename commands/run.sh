#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== $(date -u '+%H:%M UTC')  NY=$(TZ=America/New_York date '+%H:%M') ==="
echo "Service: $(systemctl is-active futures-bot)  PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- journalctl last 20 ---"
journalctl -u futures-bot --no-pager -n 20 2>&1 | tail -20
echo ""
echo "--- bot log tail 30 ---"
tail -30 logs/bot.log 2>/dev/null
