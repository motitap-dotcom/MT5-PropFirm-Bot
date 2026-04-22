#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== $(date -u '+%H:%M UTC')  NY=$(TZ=America/New_York date '+%H:%M') ==="
echo "Service: $(systemctl is-active futures-bot)  PID: $(systemctl show futures-bot --property=MainPID --value)  NRestarts: $(systemctl show futures-bot --property=NRestarts --value)"
echo ""
echo "--- journalctl last 60 ---"
journalctl -u futures-bot --no-pager -n 60 2>&1 | tail -60
echo ""
echo "--- bot log tail 40 ---"
tail -40 logs/bot.log 2>/dev/null
