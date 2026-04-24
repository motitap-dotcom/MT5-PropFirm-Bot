#!/bin/bash
# READ-ONLY check - status + positions + recent trades
cd /root/MT5-PropFirm-Bot
echo "=== Status $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
echo "NY Time: $(TZ=America/New_York date '+%H:%M %Z')"
echo ""

PID=$(systemctl show futures-bot --property=MainPID --value)
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
echo "Active: $(systemctl is-active futures-bot)"
echo "PID: $PID  CWD: $CWD"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "Git: $(git log -1 --oneline)"
echo ""

echo "--- Last trade-related log lines ---"
LOG="$CWD/logs/bot.log"
[ ! -f "$LOG" ] && LOG=/root/MT5-PropFirm-Bot/logs/bot.log
grep -iE "TRADE|SIGNAL|order placed|Position" "$LOG" 2>/dev/null | tail -10
echo ""

echo "--- Positions + fills (live from Tradovate) ---"
TOKEN=$(python3 -c "import json;print(json.load(open('$CWD/configs/.tradovate_token.json')).get('access_token',''))" 2>/dev/null)
[ -z "$TOKEN" ] && TOKEN=$(python3 -c "import json;print(json.load(open('/root/MT5-PropFirm-Bot/configs/.tradovate_token.json')).get('access_token',''))" 2>/dev/null)
BASE="https://demo.tradovateapi.com/v1"

curl -s -H "Authorization: Bearer $TOKEN" "$BASE/position/list" | python3 -c "
import sys, json
d = json.load(sys.stdin)
opn = [p for p in d if p.get('netPos',0) != 0]
print(f'Open positions: {len(opn)}')
for p in opn:
    print(f\"  id={p.get('id')} contract={p.get('contractId')} netPos={p.get('netPos')} bought={p.get('bought',0)} sold={p.get('sold',0)}\")" 2>/dev/null

curl -s -H "Authorization: Bearer $TOKEN" "$BASE/fill/list" | python3 -c "
import sys, json
from datetime import datetime, timezone
d = json.load(sys.stdin)
today = datetime.now(timezone.utc).strftime('%Y-%m-%d')
f = [x for x in d if x.get('timestamp','').startswith(today)]
print(f'Fills today: {len(f)}')
for fill in f[-10:]:
    print(f\"  {fill.get('timestamp')} {fill.get('action')} qty={fill.get('qty')} price={fill.get('price')}\")" 2>/dev/null

curl -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -X POST "$BASE/cashBalance/getCashBalanceSnapshot" -d '{"accountId":45373493}' | \
  python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f\"Balance: \${d.get('totalCashValue', 0):,.2f}  Day PnL: \${d.get('realizedPnL', 0):+.2f}  Open PnL: \${d.get('openPnL', 0):+.2f}\")" 2>/dev/null

echo ""
echo "=== Done ==="
