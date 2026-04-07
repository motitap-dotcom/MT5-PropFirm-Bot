#!/bin/bash
# Trigger: v153-check-ws-fix
cd /root/MT5-PropFirm-Bot
echo "=== v153 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Code: $(git log -1 --oneline)"
echo ""
echo "--- Bot Log (last 40) ---"
tail -40 logs/bot.log 2>/dev/null || echo "No log"
echo ""
echo "--- Journal (last 10) ---"
journalctl -u futures-bot --no-pager -n 10 2>&1
echo "=== END ==="
