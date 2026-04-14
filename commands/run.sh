#!/bin/bash
# Trigger: trading-check-2026-04-14
cd /root/MT5-PropFirm-Bot
echo "=== Trading Check $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "ET time: $(TZ='America/New_York' date '+%Y-%m-%d %H:%M %Z')"
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- status.json ---"
cat status/status.json 2>/dev/null || echo "no status.json"
echo ""
echo "--- Last 'Trading cycle' lines (trading activity) ---"
grep -E "Trading cycle|Position|Order|Filled|ENTRY|EXIT|SIGNAL|balance|Balance" logs/bot.log 2>/dev/null | tail -40
echo ""
echo "--- Last 15 log lines ---"
tail -15 logs/bot.log 2>/dev/null
echo ""
echo "--- Error count last hour ---"
grep -c "ERROR" logs/bot.log 2>/dev/null || echo "0"
echo ""
echo "--- Auth status ---"
grep -E "Authenticated|Token|auth" logs/bot.log 2>/dev/null | tail -10
