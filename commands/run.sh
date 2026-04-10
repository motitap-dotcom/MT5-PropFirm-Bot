#!/bin/bash
# Trigger: v191
cd /root/MT5-PropFirm-Bot
echo "=== v191 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- TRADES / ORDERS ---"
grep -i -E "TRADE:|Market order|placed|fill|Placing|execute_trade|blocked|Position size" logs/bot.log 2>/dev/null | grep "2026-04-10" | tail -15
echo ""
echo "--- SIGNALS on live bars (after 15:07) ---"
grep "SIGNAL" logs/bot.log 2>/dev/null | grep "2026-04-10 15:" | grep -v "14:58:28" | tail -10
echo ""
echo "--- Live VWAP (latest) ---"
grep -E "dist=|New bar" logs/bot.log 2>/dev/null | grep "2026-04-10 15:" | grep -v "14:58" | tail -12
echo ""
echo "--- Errors ---"
grep "ERROR" logs/bot.log 2>/dev/null | grep "2026-04-10 15:" | tail -5
