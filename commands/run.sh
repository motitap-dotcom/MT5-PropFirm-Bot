#!/bin/bash
# Trigger: v152 - check if bot is trading
cd /root/MT5-PropFirm-Bot
echo "=== TRADING CHECK v152 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- Status JSON ---"
cat status/status.json 2>/dev/null || echo "No status.json"
echo ""
echo "--- Last 50 log lines ---"
tail -50 logs/bot.log 2>/dev/null
echo ""
echo "--- Trading activity (signals/orders/trades) ---"
grep -i -E "signal|order|trade|fill|entry|exit|position|buy|sell|placed|cancel" logs/bot.log 2>/dev/null | tail -20
echo ""
echo "--- Guardian state ---"
grep -i "guardian" logs/bot.log 2>/dev/null | tail -10
echo ""
echo "--- Errors (last 10) ---"
grep -i "error" logs/bot.log 2>/dev/null | tail -10
