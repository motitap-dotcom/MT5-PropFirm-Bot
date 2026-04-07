#!/bin/bash
# Trigger: v155-final-check
cd /root/MT5-PropFirm-Bot
echo "=== v155 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Code: $(git log -1 --oneline)"
echo ""
echo "--- Bot Log (last 50) ---"
tail -50 logs/bot.log 2>/dev/null || echo "No log"
echo "=== END ==="
