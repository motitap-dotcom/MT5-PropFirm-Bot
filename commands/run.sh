#!/bin/bash
# Trigger: v166
cd /root/MT5-PropFirm-Bot
echo "=== v166 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo ""
tail -40 logs/bot.log 2>/dev/null
echo ""
echo "--- Signals/Trades ---"
grep -i -E "SIGNAL|LONG|SHORT|order|placed|fill|execute" logs/bot.log 2>/dev/null | tail -10
