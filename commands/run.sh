#!/bin/bash
# Trigger: v156 - check if wrapper script fix worked
cd /root/MT5-PropFirm-Bot
echo "=== Wrapper Check v156 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- Service ExecStart ---"
grep ExecStart /etc/systemd/system/futures-bot.service 2>/dev/null
echo ""
echo "--- start_bot.sh exists? ---"
ls -la /root/MT5-PropFirm-Bot/start_bot.sh 2>/dev/null || echo "start_bot.sh NOT FOUND"
echo ""
echo "--- Journal (last 15) ---"
journalctl -u futures-bot --no-pager -n 15 2>&1
echo ""
echo "--- Bot Log (last 10) ---"
tail -10 logs/bot.log 2>/dev/null
