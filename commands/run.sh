#!/bin/bash
# Trigger: v152 - post-fix verification
cd /root/MT5-PropFirm-Bot
echo "=== v152 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "SubState: $(systemctl show futures-bot --property=SubState --value)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "Restarts: $(systemctl show futures-bot --property=NRestarts --value)"
echo ""
echo "=== Service file PYTHONPATH check ==="
grep -E "PYTHONPATH|WorkingDirectory|ExecStart" /etc/systemd/system/futures-bot.service
echo ""
echo "=== LAST 10 JOURNALCTL ==="
journalctl -u futures-bot -n 15 --no-pager 2>&1 | tail -20
echo ""
echo "=== Python processes ==="
ps aux | grep -E "futures_bot|python3 -m" | grep -v grep
echo ""
echo "=== STATUS.JSON ==="
cat status/status.json 2>/dev/null
echo ""
echo "=== BOT LOG SINCE 14:15 ==="
awk '/2026-04-13 14:1[5-9]|2026-04-13 14:[2-5]/' logs/bot.log 2>/dev/null | tail -40
