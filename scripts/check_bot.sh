#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== Open Trades Check $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="
echo "ET: $(TZ='America/New_York' date '+%H:%M %Z')"
echo ""

echo "--- Service ---"
echo "State:  $(systemctl is-active futures-bot)"
echo "PID:    $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""

echo "--- status.json (positions + guardian) ---"
if [ -f status/status.json ]; then
  AGE=$(( $(date +%s) - $(stat -c %Y status/status.json) ))
  echo "status.json age: ${AGE}s ago"
  cat status/status.json
else
  echo "status.json: MISSING"
fi
echo ""

echo "--- dashboard.txt (human readable) ---"
if [ -f status/dashboard.txt ]; then
  cat status/dashboard.txt
else
  echo "dashboard.txt: not rendered"
fi
echo ""

echo "--- Position sync events (last 10) ---"
grep -E "Position sync|netPos|open_positions" logs/bot.log 2>/dev/null | tail -10
echo ""

echo "--- SIGNAL events today ---"
grep -E "SIGNAL" logs/bot.log 2>/dev/null | grep "2026-04-14" | tail -15
echo ""

echo "--- Order placements / fills today ---"
grep -E "Market order placed|Stop order|Limit order|Filled|ENTRY|EXIT|Cancelled order" logs/bot.log 2>/dev/null | grep "2026-04-14" | tail -20
echo ""

echo "--- Balance / PnL lines today ---"
grep -E "balance|Balance|PnL|drawdown" logs/bot.log 2>/dev/null | grep "2026-04-14" | tail -10
echo ""

echo "--- trades_log.csv ---"
if [ -f logs/trades_log.csv ]; then
  echo "Total lines: $(wc -l < logs/trades_log.csv)"
  echo "Header + last 10 rows:"
  head -1 logs/trades_log.csv
  tail -10 logs/trades_log.csv
else
  echo "trades_log.csv: not created yet"
fi
echo ""

echo "--- Last 15 log lines ---"
tail -15 logs/bot.log 2>/dev/null

echo ""
echo "=== END ==="
