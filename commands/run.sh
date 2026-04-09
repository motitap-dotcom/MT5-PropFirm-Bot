#!/bin/bash
# Trigger: v150 - post-fix status check
cd /root/MT5-PropFirm-Bot
echo "=== POST-FIX STATUS v150 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- Service ---"
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- Code on VPS ---"
echo "Branch: $(git branch --show-current)"
echo "Commit: $(git log -1 --oneline)"
echo "Has auth cooldown: $(grep -c 'auth_cooldown' futures_bot/core/tradovate_client.py)"
echo "Has wait_for_selector: $(grep -c 'wait_for_selector' futures_bot/core/tradovate_client.py)"
echo ""
echo "--- Directories ---"
ls -la status/ 2>/dev/null || echo "status/ MISSING"
ls -la logs/ 2>/dev/null | head -5
echo ""
echo "--- .env check ---"
for var in TRADOVATE_USER TRADOVATE_PASS TELEGRAM_TOKEN TELEGRAM_CHAT_ID; do
    if grep -q "^${var}=" .env 2>/dev/null; then
        echo "$var: SET"
    else
        echo "$var: MISSING!"
    fi
done
echo ""
echo "--- Last 30 log lines ---"
tail -30 logs/bot.log 2>/dev/null || echo "No log file"
