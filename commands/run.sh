#!/bin/bash
# Trigger: v186
cd /root/MT5-PropFirm-Bot
echo "=== v186 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- WS disconnects? ---"
grep "WebSocket disconnected" logs/bot.log 2>/dev/null | grep "2026-04-10 14:3\|2026-04-10 14:4\|2026-04-10 14:5" | wc -l
echo ""
echo "--- Bars + VWAP + Signals + Trades (after 14:28) ---"
grep "2026-04-10 14:[3-5]" logs/bot.log 2>/dev/null | grep -E "New bar|dist=|SIGNAL|order|placed|fill|TRADE|execute|Error" | tail -25
echo ""
echo "--- Last 15 ---"
tail -15 logs/bot.log 2>/dev/null
