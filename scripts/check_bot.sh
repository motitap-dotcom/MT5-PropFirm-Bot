#!/bin/bash
echo "=== v161 trend-day fix verify ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

PID=$(systemctl show futures-bot --property=MainPID --value)
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
echo "Active: $(systemctl is-active futures-bot)"
echo "PID: $PID"
echo "CWD: $CWD"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""

echo "--- Does running code have the fixes? ---"
grep -c "len(self._bars) >= 6" "$CWD/futures_bot/strategies/vwap_mean_reversion.py" 2>/dev/null && echo "trend-day fix: YES" || echo "trend-day fix: NO"
grep -c "backfill strategy state" "$CWD/futures_bot/bot.py" 2>/dev/null && echo "backfill fix: YES" || echo "backfill fix: NO"
echo ""

LOG="$CWD/logs/bot.log"
echo "--- Last 50 lines of bot log ---"
tail -50 "$LOG" 2>/dev/null
echo ""

echo "--- Strategy + trade activity ---"
grep -iE "Price=|VWAP=|RSI=|signal|entry|order|trade|Trend day" "$LOG" 2>/dev/null | tail -20
echo ""

echo "--- Positions + recent fills ---"
TOKEN=$(python3 -c "import json;print(json.load(open('$CWD/configs/.tradovate_token.json')).get('access_token',''))" 2>/dev/null)
[ -z "$TOKEN" ] && TOKEN=$(python3 -c "import json;print(json.load(open('/root/MT5-PropFirm-Bot/configs/.tradovate_token.json')).get('access_token',''))" 2>/dev/null)
BASE="https://demo.tradovateapi.com/v1"

echo "Positions:"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/position/list" | python3 -c "
import sys, json
data = json.load(sys.stdin)
open_ones = [p for p in data if p.get('netPos',0) != 0]
print(f'  {len(open_ones)} open')
for p in open_ones:
    print(f\"    contract={p.get('contractId')} netPos={p.get('netPos')} avg={p.get('avgPrice')}\")" 2>/dev/null

echo "Recent fills today:"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/fill/list" | python3 -c "
import sys, json
from datetime import datetime, timezone
data = json.load(sys.stdin)
today = datetime.now(timezone.utc).strftime('%Y-%m-%d')
fills = [f for f in data if f.get('timestamp','').startswith(today)]
print(f'  {len(fills)} fills today (total in list: {len(data)})')
for f in fills[-5:]:
    print(f\"    {f.get('timestamp')} {f.get('action')} qty={f.get('qty')} price={f.get('price')}\")" 2>/dev/null
echo ""

echo "=== Done ==="
