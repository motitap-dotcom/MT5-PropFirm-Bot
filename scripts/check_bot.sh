#!/bin/bash
echo "=== v169 verify ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"

PID=$(systemctl show futures-bot --property=MainPID --value)
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
echo "Active: $(systemctl is-active futures-bot)  PID: $PID  CWD: $CWD"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""

echo "--- Does running code have WS getChart? ---"
grep -c "WebSocket md/getChart" "$CWD/futures_bot/core/tradovate_client.py" 2>/dev/null && echo "YES" || echo "NO"
echo ""

echo "--- Log: last 50 lines (look for 'Subscribing to chart', 'got X bars', 'Price=') ---"
tail -50 "$CWD/logs/bot.log" 2>/dev/null
echo ""

echo "--- Positions ---"
TOKEN=$(python3 -c "import json;print(json.load(open('$CWD/configs/.tradovate_token.json')).get('access_token',''))" 2>/dev/null)
[ -z "$TOKEN" ] && TOKEN=$(python3 -c "import json;print(json.load(open('/root/MT5-PropFirm-Bot/configs/.tradovate_token.json')).get('access_token',''))" 2>/dev/null)
curl -s -H "Authorization: Bearer $TOKEN" "https://demo.tradovateapi.com/v1/position/list" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    o=[p for p in d if p.get('netPos',0)!=0]
    print(f'Open positions: {len(o)}')
    for p in o:
        print(f\"  {p.get('contractId')} netPos={p.get('netPos')}\")
except: print('no data')
" 2>/dev/null

curl -s -H "Authorization: Bearer $TOKEN" "https://demo.tradovateapi.com/v1/fill/list" | python3 -c "
import sys,json,datetime
d=json.load(sys.stdin)
t=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d')
f=[x for x in d if x.get('timestamp','').startswith(t)]
print(f'Fills today: {len(f)}')
for fill in f[-3:]: print(f\"  {fill.get('timestamp')} {fill.get('action')} qty={fill.get('qty')} price={fill.get('price')}\")
" 2>/dev/null
echo ""

echo "=== Done ==="
