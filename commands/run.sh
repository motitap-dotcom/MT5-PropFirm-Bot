#!/bin/bash
# Trigger: v151 - deep diagnostic
cd /root/MT5-PropFirm-Bot
echo "=== v151 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "SubState: $(systemctl show futures-bot --property=SubState --value)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "ExitCode: $(systemctl show futures-bot --property=ExecMainStatus --value)"
echo "Restarts: $(systemctl show futures-bot --property=NRestarts --value)"
echo "Code: $(git log -1 --oneline)"
echo ""
echo "=== JOURNALCTL (last 80 lines) ==="
journalctl -u futures-bot -n 80 --no-pager 2>&1
echo ""
echo "=== BOT LOG LINES SINCE 13:56 ==="
awk '/2026-04-13 13:5[6-9]|2026-04-13 14:/' logs/bot.log 2>/dev/null | tail -60
echo ""
echo "=== STATUS.JSON ==="
cat status/status.json 2>/dev/null
echo ""
echo "=== LS status/ ==="
ls -la status/ 2>/dev/null
