#!/bin/bash
# Trigger: v159 - check trading signals
cd /root/MT5-PropFirm-Bot
echo "=== TRADING SIGNALS CHECK v159 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- Last 80 log lines ---"
tail -80 logs/bot.log 2>/dev/null
echo ""
echo "--- Signals/Orders/Trades ---"
grep -i -E "signal|LONG|SHORT|order|trade|fill|entry|placed|new bar|trading cycle" logs/bot.log 2>/dev/null | tail -30
echo ""
echo "--- Status JSON ---"
cat status/status.json 2>/dev/null || echo "No status.json"
