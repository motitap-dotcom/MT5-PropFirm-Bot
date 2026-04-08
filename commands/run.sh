#!/bin/bash
# Trigger: v149
cd /root/MT5-PropFirm-Bot
echo "=== Bot Status Check v149 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- Service Status ---"
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- Latest Code ---"
echo "Code: $(git log -1 --oneline)"
echo ""
echo "--- Last 40 Lines of Bot Log ---"
tail -40 logs/bot.log 2>/dev/null
echo ""
echo "--- Status JSON ---"
cat status/status.json 2>/dev/null || echo "No status.json found"
echo ""
echo "--- Account/Balance Info ---"
tail -5 logs/bot.log 2>/dev/null | grep -i -E "balance|equity|pnl|account" || echo "No balance info in recent logs"
