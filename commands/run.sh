#!/bin/bash
# Trigger: v149 — post-audit validation check (READ-ONLY, no restart)
cd /root/MT5-PropFirm-Bot
echo "=== v149 post-audit $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- SERVICE ---"
echo "Service: $(systemctl is-active futures-bot)"
echo "PID:     $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime:  $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- CODE ---"
echo "Branch:  $(git rev-parse --abbrev-ref HEAD)"
echo "Commit:  $(git log -1 --oneline)"
echo ""
echo "--- CONFIG VALIDATION (latest log match) ---"
grep -E "(Config validation|ValueError|validation failed)" logs/bot.log 2>/dev/null | tail -10
echo ""
echo "--- NEW FILES CHECK ---"
ls -la futures_bot/core/trade_logger.py 2>/dev/null && echo "  trade_logger.py: OK" || echo "  trade_logger.py: MISSING"
ls -la scripts/weekly_review.sh 2>/dev/null && echo "  weekly_review.sh: OK" || echo "  weekly_review.sh: MISSING"
echo ""
echo "--- STATUS / DASHBOARD ---"
if [ -f status/dashboard.txt ]; then
  echo "dashboard.txt (age: $(( $(date +%s) - $(stat -c %Y status/dashboard.txt) ))s):"
  cat status/dashboard.txt
else
  echo "dashboard.txt: NOT YET RENDERED"
fi
echo ""
if [ -f status/status.json ]; then
  echo "status.json (age: $(( $(date +%s) - $(stat -c %Y status/status.json) ))s):"
  python3 -c "import json; d=json.load(open('status/status.json')); print('  state:', d.get('guardian',{}).get('state')); print('  balance:', d.get('guardian',{}).get('balance')); print('  dd_used:', d.get('guardian',{}).get('drawdown_used'))" 2>/dev/null
else
  echo "status.json: MISSING"
fi
echo ""
echo "--- TRADE LOG ---"
if [ -f logs/trades_log.csv ]; then
  wc -l logs/trades_log.csv
  head -1 logs/trades_log.csv
else
  echo "trades_log.csv: NOT YET CREATED"
fi
echo ""
echo "--- RECENT BOT LOG (last 40 lines) ---"
tail -40 logs/bot.log 2>/dev/null
echo ""
echo "=== END v149 ==="
