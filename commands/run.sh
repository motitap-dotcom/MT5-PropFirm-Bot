#!/bin/bash
# Trigger: v193
cd /root/MT5-PropFirm-Bot
echo "=== v193 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- ALL SIGNALS + TRADES + ORDERS ---"
grep -i -E "SIGNAL.*entry|TRADE:|Market order|placed|fill|blocked|Position size" logs/bot.log 2>/dev/null | grep "2026-04-10 15:1[6-9]\|2026-04-10 15:[2-5]" | tail -20
echo ""
echo "--- Last 20 ---"
tail -20 logs/bot.log 2>/dev/null
