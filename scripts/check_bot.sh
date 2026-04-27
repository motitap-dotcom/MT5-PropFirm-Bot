#!/bin/bash
echo "=== Trade investigation $(date -u '+%Y-%m-%d %H:%M UTC') | NY $(TZ=America/New_York date '+%H:%M') ==="

PID=$(systemctl show futures-bot --property=MainPID --value)
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
LOG="$CWD/logs/bot.log"

echo "Active: $(systemctl is-active futures-bot)  PID: $PID"
echo "Restart history (last 10 stops):"
tail -10 /var/log/futures-bot-stops.log 2>/dev/null
echo ""

echo "--- ALL today's trade-related events ---"
TODAY=$(date -u '+%Y-%m-%d')
grep -E "$TODAY.*(TRADE|Position sync|Stopping bot|TradeDay Futures Bot Starting|order placed|fill)" "$LOG" 2>/dev/null
echo ""

echo "--- Every fill from Tradovate today (with full detail) ---"
TOKEN=$(python3 -c "import json;print(json.load(open('$CWD/configs/.tradovate_token.json')).get('access_token',''))" 2>/dev/null)
BASE="https://demo.tradovateapi.com/v1"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/fill/list" | python3 -c "
import sys, json, datetime
d = json.load(sys.stdin)
today = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d')
fills = sorted([x for x in d if x.get('timestamp','').startswith(today)], key=lambda x:x.get('timestamp',''))
print(f'Total fills today: {len(fills)}')
for f in fills:
    ts = f.get('timestamp','')[11:19]
    print(f\"  {ts} {f.get('action','?'):4} qty={f.get('qty',0):2} contract={f.get('contractId','?'):6} price={f.get('price',0):.2f} fillId={f.get('id')}\")
" 2>/dev/null
echo ""

echo "--- Today's orders (active + filled) ---"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/order/list" | python3 -c "
import sys, json, datetime
d = json.load(sys.stdin)
today = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d')
orders = [o for o in d if str(o.get('timestamp','')).startswith(today)]
print(f'Orders today: {len(orders)}')
for o in orders[-15:]:
    ts = o.get('timestamp','')[11:19] if o.get('timestamp') else '?'
    print(f\"  {ts} {o.get('action','?'):4} {o.get('orderType','?'):8} qty={o.get('orderQty',0):2} status={o.get('ordStatus','?'):10} contract={o.get('contractId','?')}\")
" 2>/dev/null
echo ""

echo "--- Account: PnL by snapshot ---"
curl -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -X POST "$BASE/cashBalance/getCashBalanceSnapshot" -d '{"accountId":45373493}' | \
python3 -c "
import sys,json
d=json.load(sys.stdin)
print(f\"  Balance: \${d.get('totalCashValue',0):,.2f}\")
print(f\"  Day realized PnL: \${d.get('realizedPnL',0):+.2f}\")
print(f\"  Open PnL: \${d.get('openPnL',0):+.2f}\")
print(f\"  Week realized: \${d.get('weekRealizedPnL',0):+.2f}\")
print(f\"  Net Liq: \${d.get('netLiq',0):,.2f}\")
print(f\"  Initial margin: \${d.get('initialMargin',0):.2f}\")
" 2>/dev/null
echo ""

echo "--- Current strategy state (per symbol) ---"
grep -E "$TODAY.*strategy.vwap.*Price=" "$LOG" 2>/dev/null | tail -10

echo ""
echo "=== Done ==="
