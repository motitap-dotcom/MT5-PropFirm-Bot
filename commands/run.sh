#!/bin/bash
# Trigger: v172
cd /root/MT5-PropFirm-Bot
echo "=== v172 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "--- Signals + Orders + Trades ---"
grep -i -E "SIGNAL|order|placed|fill|execute|position|trade|LONG|SHORT" logs/bot.log 2>/dev/null | tail -20
echo ""
echo "--- Last 30 log lines ---"
tail -30 logs/bot.log 2>/dev/null
