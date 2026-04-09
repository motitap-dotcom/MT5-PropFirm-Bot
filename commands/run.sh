#!/bin/bash
# Trigger: v156 - verify WebSocket chart data working
cd /root/MT5-PropFirm-Bot
echo "=== WEBSOCKET VERIFY v156 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- Code version ---"
echo "Commit: $(git log -1 --oneline)"
echo "Has _subscribe_chart: $(grep -c '_subscribe_chart' futures_bot/core/tradovate_client.py)"
echo "Has _chart_bars: $(grep -c '_chart_bars' futures_bot/core/tradovate_client.py)"
echo ""
echo "--- Last 40 log lines ---"
tail -40 logs/bot.log 2>/dev/null
echo ""
echo "--- Chart/bars activity ---"
grep -i -E "chart|bars|subscri|WebSocket|signal|trading cycle|new bar|no bars" logs/bot.log 2>/dev/null | tail -20
