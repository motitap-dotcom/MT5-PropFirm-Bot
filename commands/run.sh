#!/bin/bash
# Trigger: trades-check v2
cd /root/MT5-PropFirm-Bot
echo "=== Trades Status $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "Code: $(git log -1 --oneline)"
echo ""
echo "--- status.json ---"
cat status/status.json 2>/dev/null || echo "No status.json found"
echo ""
echo "--- Last 50 log lines ---"
tail -50 logs/bot.log 2>/dev/null || echo "No log file"
echo ""
echo "--- Trade/Position mentions (last 30) ---"
grep -iE "(position|trade|order|filled|entry|exit|pnl|profit|loss)" logs/bot.log 2>/dev/null | tail -30 || echo "None found"
