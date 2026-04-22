#!/bin/bash
# Final check
cd /root/MT5-PropFirm-Bot
echo "=== $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)  PID: $(systemctl show futures-bot --property=MainPID --value)  NRestarts: $(systemctl show futures-bot --property=NRestarts --value)"
echo ""
echo "--- journalctl last 20 ---"
journalctl -u futures-bot --no-pager -n 20 2>&1 | tail -20
echo ""
echo "--- bot.log last 30 ---"
tail -30 logs/bot.log 2>/dev/null
echo ""
echo "--- status.json ---"
cat status/status.json 2>/dev/null
