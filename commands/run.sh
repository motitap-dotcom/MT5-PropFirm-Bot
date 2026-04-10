#!/bin/bash
# Trigger: v178
cd /root/MT5-PropFirm-Bot
echo "=== v178 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "Commit: $(git log -1 --oneline)"
echo ""
echo "--- Playwright fix deployed? ---"
echo "domcontentloaded: $(grep -c 'domcontentloaded' futures_bot/core/tradovate_client.py)"
echo "force 2h expiry: $(grep -c 'token valid for 2h' futures_bot/core/tradovate_client.py)"
echo ""
echo "--- Last 30 log lines ---"
tail -30 logs/bot.log 2>/dev/null
