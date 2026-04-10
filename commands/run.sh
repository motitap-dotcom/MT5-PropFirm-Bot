#!/bin/bash
# Trigger: v181 - after ORB period
cd /root/MT5-PropFirm-Bot
echo "=== v181 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "--- Orders/Trades ---"
grep -i -E "order|placed|fill|execute_trade|Placing|SIGNAL.*entry" logs/bot.log 2>/dev/null | grep "2026-04-10" | grep -v "13:47:3" | tail -15
echo ""
echo "--- Last 40 log ---"
tail -40 logs/bot.log 2>/dev/null
