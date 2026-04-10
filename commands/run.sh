#!/bin/bash
# Trigger: v185
cd /root/MT5-PropFirm-Bot
echo "=== v185 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- After 14:13 UTC ---"
grep "2026-04-10 14:1\|2026-04-10 14:2\|2026-04-10 14:3" logs/bot.log 2>/dev/null | grep -E "New bar|dist=|SIGNAL|order|placed|fill|execute|Trading cycle|Warming|WebSocket|Subscribing|Received|Error|TRADE" | tail -30
echo ""
echo "--- Last 15 ---"
tail -15 logs/bot.log 2>/dev/null
