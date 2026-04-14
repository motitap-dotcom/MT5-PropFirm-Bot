#!/bin/bash
# Trigger: health-confirm
cd /root/MT5-PropFirm-Bot
sleep 45  # give startup time
echo "=== Health Confirm $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "ET: $(TZ='America/New_York' date '+%H:%M %Z')"
echo ""
echo "State:  $(systemctl is-active futures-bot)"
echo "PID:    $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- Auth events since 14:36 UTC ---"
awk '/2026-04-14 14:(3[6-9]|[45][0-9])/' logs/bot.log 2>/dev/null | grep -E "Connected|Authenticated|Token|CAPTCHA|browser auth|Incorrect|Error fetching|Authentication failed" | tail -10
echo ""
echo "--- Trading cycles since 14:36 UTC ---"
awk '/2026-04-14 14:(3[6-9]|[45][0-9])/' logs/bot.log 2>/dev/null | grep -E "Trading cycle|SIGNAL|Filled|Position sync|ENTRY" | tail -10
echo ""
echo "--- Errors since 14:36 UTC ---"
awk '/2026-04-14 14:(3[6-9]|[45][0-9])/' logs/bot.log 2>/dev/null | grep ERROR | tail -5
echo ""
echo "--- Last 20 log lines ---"
tail -20 logs/bot.log 2>/dev/null
