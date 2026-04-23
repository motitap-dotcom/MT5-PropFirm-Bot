#!/bin/bash
echo "=== Trading activity check ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo "NY Time: $(TZ=America/New_York date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

echo "--- Bot state ---"
echo "Active: $(systemctl is-active futures-bot)"
PID=$(systemctl show futures-bot --property=MainPID --value)
echo "PID: $PID"
[ -n "$PID" ] && [ "$PID" != "0" ] && {
  echo "CWD: $(readlink /proc/$PID/cwd 2>/dev/null)"
  echo "Uptime since: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
}
echo ""

echo "--- Recent stops (kill pattern) ---"
tail -15 /var/log/futures-bot-stops.log 2>/dev/null
echo ""

echo "--- Positions + fills (via Tradovate API) ---"
TOKEN_FILE=/root/MT5-PropFirm-Bot/configs/.tradovate_token.json
TOKEN=$(python3 -c "import json;print(json.load(open('$TOKEN_FILE')).get('access_token',''))" 2>/dev/null)
BASE="https://demo.tradovateapi.com/v1"

echo "Open positions:"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/position/list" | python3 -c "
import sys, json
data = json.load(sys.stdin)
open_ones = [p for p in data if p.get('netPos',0) != 0]
if open_ones:
    for p in open_ones:
        print(f\"  acct={p.get('accountId')} contract={p.get('contractId')} netPos={p.get('netPos')} avg={p.get('avgPrice','?')}\")
else:
    print('  (none open)')
" 2>/dev/null
echo ""

echo "Orders:"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/order/list" | python3 -c "
import sys, json
data = json.load(sys.stdin)
active = [o for o in data if o.get('ordStatus') in ('Working','PendingNew','Accepted')]
if active:
    for o in active[:5]:
        print(f\"  id={o.get('id')} symbol={o.get('contractId')} action={o.get('action')} qty={o.get('orderQty')} status={o.get('ordStatus')}\")
else:
    print('  (no active orders)')
    print(f'  total orders in history: {len(data)}')
" 2>/dev/null
echo ""

echo "Recent fills (today):"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/fill/list" | python3 -c "
import sys, json
from datetime import datetime, timezone
data = json.load(sys.stdin)
today = datetime.now(timezone.utc).strftime('%Y-%m-%d')
today_fills = [f for f in data if f.get('timestamp','').startswith(today)]
if today_fills:
    for f in today_fills[-10:]:
        print(f\"  {f.get('timestamp')} symbol={f.get('contractId')} action={f.get('action')} qty={f.get('qty')} price={f.get('price')}\")
else:
    print(f'  (no fills today. Total fills in list: {len(data)})')
" 2>/dev/null
echo ""

echo "--- Bot log: signals/trades from last 10 min ---"
LOG=/root/MT5-PropFirm-Bot/logs/bot.log
[ ! -f "$LOG" ] && LOG=/opt/futures_bot_stable/logs/bot.log
if [ -f "$LOG" ]; then
  echo "Log file: $LOG"
  tail -200 "$LOG" 2>/dev/null | grep -iE "signal|entry|trade|order|position|vwap|orb|skip|blocked|no trade" | tail -30
else
  echo "No log found"
fi
echo ""

echo "--- Balance ---"
curl -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -X POST "$BASE/cashBalance/getCashBalanceSnapshot" \
  -d '{"accountId":45373493}' | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f\"  totalCashValue: \${d.get('totalCashValue',0):.2f}\")
print(f\"  realizedPnL today: \${d.get('realizedPnL',0):.2f}\")
print(f\"  openPnL: \${d.get('openPnL',0):.2f}\")
print(f\"  weekRealizedPnL: \${d.get('weekRealizedPnL',0):.2f}\")
" 2>/dev/null

echo ""
echo "=== Done ==="
