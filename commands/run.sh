#!/bin/bash
# Trigger: v159 - verify direct bot.py execution fix
cd /root/MT5-PropFirm-Bot
echo "=== Verify v159 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- ExecStart ---"
grep ExecStart /etc/systemd/system/futures-bot.service
echo ""
echo "--- Journal (last 15) ---"
journalctl -u futures-bot --no-pager -n 15 2>&1
echo ""
echo "--- Bot Log (last 15) ---"
tail -15 logs/bot.log 2>/dev/null
