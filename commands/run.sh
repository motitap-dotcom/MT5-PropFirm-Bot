#!/bin/bash
# Trigger: v182 - after 10:00 ET
cd /root/MT5-PropFirm-Bot
echo "=== v182 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "--- Live VWAP + signals after 14:00 UTC ---"
grep -E "dist=|SIGNAL|order|placed|fill|execute" logs/bot.log 2>/dev/null | grep -E "2026-04-10 1[4-9]:" | tail -20
echo ""
echo "--- Last 20 log ---"
tail -20 logs/bot.log 2>/dev/null
