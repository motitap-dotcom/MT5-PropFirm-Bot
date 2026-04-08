#!/bin/bash
# Trigger: v152 - check if bot is actively trading
cd /root/MT5-PropFirm-Bot
echo "=== Trading Check v152 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- Open Positions ---"
tail -100 logs/bot.log 2>/dev/null | grep -i -E "position|order|fill|trade|signal|entry|exit|buy|sell|placed|blocked" | tail -20
echo ""
echo "--- Last 30 Bot Log Lines ---"
tail -30 logs/bot.log 2>/dev/null
echo ""
echo "--- Status JSON ---"
cat status/status.json 2>/dev/null || echo "No status.json"
