#!/bin/bash
# Trigger: diagnose-no-trades
cd /root/MT5-PropFirm-Bot
echo "=== Why No Trades $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- status.json ---"
cat status/status.json 2>/dev/null || echo "none"
echo ""
echo "--- Guardian state + trade signals in log ---"
grep -iE "(guardian|signal|trade|block|reject|skip|flatten|news|restricted|blocked|entry)" logs/bot.log 2>/dev/null | tail -40
echo ""
echo "--- Last 30 log lines ---"
tail -30 logs/bot.log 2>/dev/null
echo ""
echo "--- Account info ---"
grep -iE "(balance|equity|pnl|account|positions|margin)" logs/bot.log 2>/dev/null | tail -15
