#!/bin/bash
# Trigger: v151-check-after-fix
cd /root/MT5-PropFirm-Bot
echo "=== v151 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Code: $(git log -1 --oneline)"
echo "Branch: $(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD)"
echo ""
echo "--- Journal (last 15) ---"
journalctl -u futures-bot --no-pager -n 15 2>&1
echo ""
echo "--- Bot Log (last 30) ---"
tail -30 logs/bot.log 2>/dev/null || echo "No log"
echo "=== END ==="
