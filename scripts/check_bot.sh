#!/bin/bash
echo "=== Reject reason hunt $(date -u '+%Y-%m-%d %H:%M UTC') ==="
PID=$(systemctl show futures-bot --property=MainPID --value)
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
TOKEN=$(python3 -c "import json;print(json.load(open('$CWD/configs/.tradovate_token.json')).get('access_token',''))" 2>/dev/null)
BASE="https://demo.tradovateapi.com/v1"
TODAY=$(date -u '+%Y-%m-%d')

echo "--- Order extension info (rejection reason lives here) ---"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/orderVersion/list" | python3 -c "
import sys,json
d=json.load(sys.stdin)
today=[o for o in d if str(o.get('timestamp','')).startswith('$TODAY')]
print(f'Order versions today: {len(today)}')
for o in today[:5]:
    print(json.dumps(o, indent=2))
    print('---')
" 2>/dev/null
echo ""

echo "--- commandReport for first order (placement details) ---"
ORDER_ID=$(curl -s -H "Authorization: Bearer $TOKEN" "$BASE/order/list" | python3 -c "
import sys,json
d=json.load(sys.stdin)
today=[o for o in d if str(o.get('timestamp','')).startswith('$TODAY') and o.get('ordStatus')=='Rejected']
if today: print(today[0].get('id',''))
" 2>/dev/null)
echo "First rejected orderId: $ORDER_ID"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/commandReport/list" | python3 -c "
import sys,json
d=json.load(sys.stdin)
today=[c for c in d if str(c.get('timestamp','')).startswith('$TODAY')]
print(f'Command reports today: {len(today)}')
for c in today[:5]:
    print(json.dumps(c, indent=2))
    print('---')
" 2>/dev/null
echo ""

echo "--- Max position permission check ---"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/maxPositionPermission/list" | python3 -m json.tool 2>&1 | head -30
echo ""

echo "--- Account risk ---"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/cashBalance/list" | python3 -m json.tool 2>&1 | head -30
echo ""

echo "--- contractMaximums for our symbols ---"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/contractMaximum/list" | python3 -m json.tool 2>&1 | head -30
echo ""

echo "=== Done ==="
