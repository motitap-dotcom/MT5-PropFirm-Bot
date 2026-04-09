#!/bin/bash
# Trigger: v153 - check diagnostic logs
cd /root/MT5-PropFirm-Bot
echo "=== DIAGNOSTIC v153 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- Code on VPS ---"
echo "Commit: $(git log -1 --oneline)"
echo "Has bar logging: $(grep -c 'New bar' futures_bot/bot.py)"
echo "Has cycle logging: $(grep -c 'Trading cycle' futures_bot/bot.py)"
echo ""
echo "--- Last 40 log lines ---"
tail -40 logs/bot.log 2>/dev/null
echo ""
echo "--- Any bars received? ---"
grep -i "new bar\|no bars\|outside session\|trading cycle" logs/bot.log 2>/dev/null | tail -15
