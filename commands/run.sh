#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== Status $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "Uptime since: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- Status JSON ---"
cat status/status.json 2>/dev/null || echo "No status.json yet"
echo ""
echo "--- Last 15 log lines ---"
tail -15 logs/bot.log 2>/dev/null
