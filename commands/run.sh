#!/bin/bash
# Trigger: check-trades-v1
cd /root/MT5-PropFirm-Bot
echo "=== Trade Check $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- Service Status ---"
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- Status JSON ---"
cat status/status.json 2>/dev/null || echo "No status.json found"
echo ""
echo "--- Recent Trade Activity (last 50 log lines) ---"
tail -50 logs/bot.log 2>/dev/null | grep -iE "trade|order|position|entry|exit|buy|sell|long|short|signal|placed|filled|open|close|contract|MES|MNQ|MES|NQ|ES|rejected|denied|guardian|blocked|no.*signal|waiting" || echo "No trade-related lines found"
echo ""
echo "--- Last 20 Log Lines (raw) ---"
tail -20 logs/bot.log 2>/dev/null
