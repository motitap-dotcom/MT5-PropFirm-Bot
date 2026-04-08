#!/bin/bash
# Trigger: v151 - verify bot is running after fix
cd /root/MT5-PropFirm-Bot
echo "=== Post-Fix Check v151 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "Restarts: $(systemctl show futures-bot --property=NRestarts --value)"
echo ""
echo "--- Journal (last 20 lines) ---"
journalctl -u futures-bot --no-pager -n 20 --since "5 min ago" 2>&1
echo ""
echo "--- Bot Log (last 15 lines) ---"
tail -15 logs/bot.log 2>/dev/null
echo ""
echo "--- Files check ---"
ls -la futures_bot/__init__.py 2>/dev/null
ls -la futures_bot/bot.py 2>/dev/null
