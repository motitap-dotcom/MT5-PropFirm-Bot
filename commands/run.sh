#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== Check after v175 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
PID=$(systemctl show futures-bot --property=MainPID --value)
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
echo "Active: $(systemctl is-active futures-bot)  PID: $PID  CWD: $CWD"
echo ""
echo "--- Does tradovate_client accept kwargs? ---"
grep -c '\*\*kwargs' "$CWD/futures_bot/core/tradovate_client.py"
echo ""
echo "--- Log tail ---"
tail -30 "$CWD/logs/bot.log" 2>/dev/null
echo ""
echo "--- Positions + fills ---"
TOKEN=$(python3 -c "import json;print(json.load(open('$CWD/configs/.tradovate_token.json')).get('access_token',''))" 2>/dev/null)
BASE="https://demo.tradovateapi.com/v1"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/position/list" | python3 -c "
import sys,json
d=json.load(sys.stdin)
o=[p for p in d if p.get('netPos',0)!=0]
print(f'Open: {len(o)}')
for p in o: print(f\"  {p.get('contractId')} netPos={p.get('netPos')}\")
" 2>/dev/null
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/fill/list" | python3 -c "
import sys,json,datetime
d=json.load(sys.stdin)
t=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d')
f=[x for x in d if x.get('timestamp','').startswith(t)]
print(f'Fills today: {len(f)}')
for x in f[-5:]: print(f\"  {x.get('timestamp')} {x.get('action')} qty={x.get('qty')} price={x.get('price')}\")
" 2>/dev/null
echo ""
echo "=== Done ==="
