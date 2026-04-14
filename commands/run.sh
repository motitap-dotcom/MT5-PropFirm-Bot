#!/bin/bash
# Trigger: final-verify-post-restart
cd /root/MT5-PropFirm-Bot
echo "=== Final Verify $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "ET: $(TZ='America/New_York' date '+%H:%M %Z')"
echo ""
echo "--- Service ---"
echo "State:  $(systemctl is-active futures-bot)"
echo "PID:    $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- Fix verification (must be 1,1) ---"
echo "bot.py keepalive: $(grep -c 'Token keepalive failed' futures_bot/bot.py)"
echo "client.py browser fallback: $(grep -c 'browser auth as last resort' futures_bot/core/tradovate_client.py)"
echo ""
echo "--- Last 5 auth events ---"
grep -E "Connected to Tradovate|Authenticated|Token renewed|CAPTCHA|browser auth|Incorrect username" logs/bot.log 2>/dev/null | tail -5
echo ""
echo "--- Last 5 trading cycles / signals ---"
grep -E "Trading cycle|SIGNAL|Filled|ENTRY" logs/bot.log 2>/dev/null | tail -10
echo ""
echo "--- Last 3 errors (if any) ---"
grep ERROR logs/bot.log 2>/dev/null | tail -3
echo ""
echo "--- status.json ---"
cat status/status.json 2>/dev/null | head -20
