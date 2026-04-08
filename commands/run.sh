#!/bin/bash
# Trigger: v157 - verify bash -c fix
cd /root/MT5-PropFirm-Bot
echo "=== Verify v157 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- ExecStart line ---"
grep ExecStart /etc/systemd/system/futures-bot.service
echo ""
echo "--- Journal (last 15) ---"
journalctl -u futures-bot --no-pager -n 15 2>&1
echo ""
echo "--- Bot Log (last 10) ---"
tail -10 logs/bot.log 2>/dev/null
