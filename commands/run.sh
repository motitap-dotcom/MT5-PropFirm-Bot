#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== $(date -u '+%H:%M UTC')  NY=$(TZ=America/New_York date '+%H:%M') ==="
echo "Service: $(systemctl is-active futures-bot)  PID: $(systemctl show futures-bot --property=MainPID --value)  NRestarts: $(systemctl show futures-bot --property=NRestarts --value)  Since: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- wrapper exists? ---"
ls -la /usr/local/sbin/futures-bot-wrapper.sh
echo ""
echo "--- journalctl last 25 ---"
journalctl -u futures-bot --no-pager -n 25 2>&1 | tail -25
echo ""
echo "--- bot log last 25 ---"
tail -25 logs/bot.log
