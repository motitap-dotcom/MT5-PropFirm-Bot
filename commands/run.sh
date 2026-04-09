#!/bin/bash
# Trigger: v149
cd /root/MT5-PropFirm-Bot
echo "=== STATUS CHECK v149 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- Service ---"
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- Code ---"
echo "Branch: $(git branch --show-current)"
echo "Commit: $(git log -1 --oneline)"
echo ""
echo "--- Last 40 lines of log ---"
tail -40 logs/bot.log 2>/dev/null
echo ""
echo "--- Status JSON ---"
cat status/status.json 2>/dev/null || echo "No status.json found"
echo ""
echo "--- Account / Positions ---"
cat logs/bot.log 2>/dev/null | grep -i -E "balance|position|P&L|pnl|drawdown|trade|order|fill" | tail -15
