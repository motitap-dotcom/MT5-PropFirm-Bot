#!/bin/bash
# Trigger: post-restart-verify-v20
cd /root/MT5-PropFirm-Bot
echo "=== Post-Restart Verify $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "ET time: $(TZ='America/New_York' date '+%Y-%m-%d %H:%M %Z')"
echo "Commit: $(git log -1 --oneline)"
echo ""
echo "--- Service ---"
echo "State:  $(systemctl is-active futures-bot)"
echo "PID:    $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- Auth / token signals in last log lines ---"
grep -E "Authenticated|Token|renewed|browser auth|CAPTCHA|Playwright|Connected to Tradovate|Incorrect username" logs/bot.log 2>/dev/null | tail -20
echo ""
echo "--- status.json ---"
cat status/status.json 2>/dev/null || echo "no status.json"
echo ""
echo "--- Last 25 log lines ---"
tail -25 logs/bot.log 2>/dev/null
echo ""
echo "--- Position list (if auth works) ---"
grep -E "Position sync|SIGNAL|ENTRY|Filled|Error fetching balance|Authentication failed" logs/bot.log 2>/dev/null | tail -15
