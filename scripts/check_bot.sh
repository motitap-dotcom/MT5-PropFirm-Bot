#!/bin/bash
echo "=== Order rejection investigation $(date -u '+%Y-%m-%d %H:%M UTC') ==="

PID=$(systemctl show futures-bot --property=MainPID --value)
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
LOG="$CWD/logs/bot.log"
TODAY=$(date -u '+%Y-%m-%d')
TOKEN=$(python3 -c "import json;print(json.load(open('$CWD/configs/.tradovate_token.json')).get('access_token',''))" 2>/dev/null)
BASE="https://demo.tradovateapi.com/v1"

echo "--- Full order details for first 5 orders today ---"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/order/list" | python3 -c "
import sys, json
d = json.load(sys.stdin)
today_orders = sorted([o for o in d if str(o.get('timestamp','')).startswith('$TODAY')], key=lambda x: x.get('timestamp',''))
for o in today_orders[:5]:
    print(json.dumps(o, indent=2))
    print('---')
" 2>/dev/null
echo ""

echo "--- Order rejection messages from log ---"
grep -E "$TODAY.*(rejected|reject|Rejected|REJECTED|HTTP error|order.*fail|Limit:)" "$LOG" 2>/dev/null | tail -15
echo ""

echo "--- All log lines around first trade attempt ---"
awk '/^2026-04-27 13:30/' "$LOG" 2>/dev/null | head -30
echo ""

echo "--- Account info ---"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/account/list" | python3 -m json.tool 2>&1 | head -20
echo ""

echo "--- Restricted/closed status ---"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/account/list" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for a in d:
    print(f'restricted: {a.get(\"restricted\")}  closed: {a.get(\"closed\")}  active: {a.get(\"active\")}  locked: {a.get(\"locked\")}')" 2>/dev/null

echo ""
echo "=== Done ==="
