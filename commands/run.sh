#!/bin/bash
# Trigger: v174 - market open check
cd /root/MT5-PropFirm-Bot
echo "=== MARKET OPEN v174 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- Last 50 log lines ---"
tail -50 logs/bot.log 2>/dev/null
echo ""
echo "--- Signals + Trades ---"
grep -i -E "SIGNAL|order|placed|fill|execute|trade|LONG|SHORT" logs/bot.log 2>/dev/null | grep "2026-04-10" | tail -15
