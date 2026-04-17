#!/bin/bash
# Trigger: quick-journal v2
cd /root/MT5-PropFirm-Bot
echo "=== Quick Check $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- journalctl last 60 lines ---"
journalctl -u futures-bot -n 60 --no-pager 2>&1 | tail -60
