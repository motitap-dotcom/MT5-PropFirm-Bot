#!/bin/bash
# Trigger: v154 - final verify bot running with all fixes
cd /root/MT5-PropFirm-Bot
echo "=== Final Check v154 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- Journal (last 15 lines) ---"
journalctl -u futures-bot --no-pager -n 15 2>&1
echo ""
echo "--- Bot Log (last 20 lines) ---"
tail -20 logs/bot.log 2>/dev/null
