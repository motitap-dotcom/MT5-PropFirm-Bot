#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== Check v176 $(date -u '+%Y-%m-%d %H:%M UTC') | NY $(TZ=America/New_York date '+%H:%M') ==="
PID=$(systemctl show futures-bot --property=MainPID --value)
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
echo "Active: $(systemctl is-active futures-bot)  PID: $PID  CWD: $CWD"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- ATR config ---"
grep -A2 "\"MES\"" "$CWD/configs/bot_config.json"
grep "max_atr" "$CWD/configs/bot_config.json" | head -2
echo ""
echo "--- Trade signals + recent strategy ---"
grep -E "SIGNAL|TRADE" "$CWD/logs/bot.log" 2>/dev/null | tail -10
echo ""
grep -E "strategy.vwap.*Price=" "$CWD/logs/bot.log" 2>/dev/null | tail -8
echo ""
echo "--- Account ---"
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
for x in f[-5:]: print(f\"  {x.get('timestamp')[11:19]} {x.get('action')} qty={x.get('qty')} price={x.get('price')}\")
" 2>/dev/null
curl -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -X POST "$BASE/cashBalance/getCashBalanceSnapshot" -d '{"accountId":45373493}' | \
python3 -c "import sys,json;d=json.load(sys.stdin);print(f\"Balance: \${d.get('totalCashValue',0):,.2f}  PnL day: \${d.get('realizedPnL',0):+.2f}  Open: \${d.get('openPnL',0):+.2f}\")" 2>/dev/null
echo ""
echo "=== Done ==="
