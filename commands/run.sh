#!/bin/bash
# Trigger: post-fix-check
cd /root/MT5-PropFirm-Bot
echo "=== Post-Fix Status $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- systemd service file (check PYTHONPATH) ---"
cat /etc/systemd/system/futures-bot.service
echo ""
echo "--- journalctl last 20 lines ---"
journalctl -u futures-bot -n 20 --no-pager 2>&1 | tail -20
