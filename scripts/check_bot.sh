#!/bin/bash
echo "=== Status $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "NY: $(TZ=America/New_York date '+%Y-%m-%d %H:%M %Z')"
echo ""

echo "Active: $(systemctl is-active futures-bot)"
PID=$(systemctl show futures-bot --property=MainPID --value)
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
echo "PID: $PID  CWD: $CWD"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""

echo "--- Today's trades from log ---"
TODAY=$(date -u '+%Y-%m-%d')
grep -E "$TODAY.*TRADE|$TODAY.*Position sync" "$CWD/logs/bot.log" 2>/dev/null | tail -15
echo ""

echo "--- Today's strategy snapshots (last 6) ---"
grep -E "$TODAY.*strategy.vwap.*Price=" "$CWD/logs/bot.log" 2>/dev/null | tail -6
echo ""

echo "--- Account balance + positions ---"
TOKEN=$(python3 -c "import json;print(json.load(open('$CWD/configs/.tradovate_token.json')).get('access_token',''))" 2>/dev/null)
BASE="https://demo.tradovateapi.com/v1"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/position/list" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    o=[p for p in d if p.get('netPos',0)!=0]
    print(f'Open positions: {len(o)}')
    for p in o: print(f\"  {p.get('contractId')} netPos={p.get('netPos')}\")
except: print('parse error')
" 2>/dev/null

curl -s -H "Authorization: Bearer $TOKEN" "$BASE/fill/list" | python3 -c "
import sys,json,datetime
try:
    d=json.load(sys.stdin)
    t=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d')
    f=[x for x in d if x.get('timestamp','').startswith(t)]
    print(f'Fills today: {len(f)}')
    for x in f[-5:]: print(f\"  {x.get('timestamp')[11:19]} {x.get('action')} qty={x.get('qty')} price={x.get('price')}\")
except: print('parse error')
" 2>/dev/null

curl -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -X POST "$BASE/cashBalance/getCashBalanceSnapshot" -d '{"accountId":45373493}' | \
python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print(f\"Balance: \${d.get('totalCashValue',0):,.2f}  Day PnL: \${d.get('realizedPnL',0):+.2f}  Open PnL: \${d.get('openPnL',0):+.2f}  Week PnL: \${d.get('weekRealizedPnL',0):+.2f}\")
except: print('parse error')
" 2>/dev/null
echo ""
echo "=== Done ==="
