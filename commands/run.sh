#!/bin/bash
# Trigger: v169
cd /root/MT5-PropFirm-Bot
echo "=== v169 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "Commit: $(git log -1 --oneline)"
echo ""
echo "--- Check if debug logging present in RUNNING process ---"
grep -c "Price=.*VWAP=" logs/bot.log 2>/dev/null || echo "0 debug log lines"
grep -c "ATR filter:" logs/bot.log 2>/dev/null || echo "0 ATR filter lines"
echo ""
echo "--- Last 15 log lines ---"
tail -15 logs/bot.log 2>/dev/null
