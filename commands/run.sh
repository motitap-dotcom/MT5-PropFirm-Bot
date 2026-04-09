#!/bin/bash
# Trigger: v158 - post-news check
cd /root/MT5-PropFirm-Bot
echo "=== POST-NEWS CHECK v158 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- Last 60 log lines ---"
tail -60 logs/bot.log 2>/dev/null
