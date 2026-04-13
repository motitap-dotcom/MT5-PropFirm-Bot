#!/bin/bash
# Trigger: v150 — post-deploy verification (READ-ONLY, bot should be active now)
cd /root/MT5-PropFirm-Bot
echo "=== v150 post-deploy $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- SERVICE ---"
echo "Service: $(systemctl is-active futures-bot)"
echo "PID:     $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime:  $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- CODE ---"
echo "Commit: $(git log -1 --oneline)"
echo ""
echo "--- CONFIG VALIDATION ---"
grep -E "Config validation" logs/bot.log 2>/dev/null | tail -5
echo ""
echo "--- STARTUP LOG (after 20:00 UTC) ---"
awk '/2026-04-13 20:/' logs/bot.log 2>/dev/null | tail -30
echo ""
echo "--- DASHBOARD ---"
if [ -f status/dashboard.txt ]; then
  echo "age: $(( $(date +%s) - $(stat -c %Y status/dashboard.txt) ))s"
  cat status/dashboard.txt
else
  echo "dashboard.txt: NOT YET"
fi
echo ""
echo "--- STATUS JSON ---"
if [ -f status/status.json ]; then
  echo "age: $(( $(date +%s) - $(stat -c %Y status/status.json) ))s"
  python3 -c "import json; d=json.load(open('status/status.json')); g=d.get('guardian',{}); print('  state:', g.get('state')); print('  balance:', g.get('balance')); print('  daily_pnl:', g.get('daily_pnl')); print('  daily_trades:', g.get('daily_trades')); print('  dd_used:', g.get('drawdown_used'))" 2>/dev/null
fi
echo ""
echo "--- TRADE LOG ---"
if [ -f logs/trades_log.csv ]; then
  wc -l logs/trades_log.csv
fi
echo ""
echo "=== END v150 ==="
