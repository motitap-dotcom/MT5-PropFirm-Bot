#!/bin/bash
# Post-deploy status check
cd /root/MT5-PropFirm-Bot
echo "=== Post-Deploy Check $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- Service ---"
systemctl is-active futures-bot
systemctl is-enabled futures-bot
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- Service File ExecStart ---"
grep "ExecStart\|PYTHONPATH" /etc/systemd/system/futures-bot.service 2>/dev/null || echo "Service file not found"
echo ""
echo "--- Code ---"
git log -1 --oneline
echo ""
echo "--- Last 20 log lines ---"
tail -20 logs/bot.log 2>/dev/null || echo "No log yet"
echo ""
echo "--- Journal (last 10) ---"
journalctl -u futures-bot --no-pager -n 10
