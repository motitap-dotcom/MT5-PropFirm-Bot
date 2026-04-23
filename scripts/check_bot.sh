#!/bin/bash
echo "=== Live strategy check ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

PID=$(systemctl show futures-bot --property=MainPID --value)
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
echo "Active: $(systemctl is-active futures-bot)"
echo "PID: $PID  CWD: $CWD"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""

echo "--- config RSI thresholds ---"
python3 -c "
import json
c = json.load(open('$CWD/configs/bot_config.json'))
print('rsi_oversold:', c['vwap']['rsi_oversold'])
print('rsi_overbought:', c['vwap']['rsi_overbought'])
" 2>/dev/null
echo ""

echo "--- diagnostic log lines (what strategy sees) ---"
grep -iE "Price=|VWAP=|ATR filter|Signal" "$CWD/logs/bot.log" 2>/dev/null | tail -30
echo ""

echo "--- Last 30 lines overall ---"
tail -30 "$CWD/logs/bot.log" 2>/dev/null
echo ""

echo "--- Positions + fills ---"
TOKEN=$(python3 -c "import json;print(json.load(open('$CWD/configs/.tradovate_token.json')).get('access_token',''))" 2>/dev/null)
BASE="https://demo.tradovateapi.com/v1"

curl -s -H "Authorization: Bearer $TOKEN" "$BASE/position/list" | python3 -c "
import sys, json
d = json.load(sys.stdin)
open_ones = [p for p in d if p.get('netPos',0) != 0]
print(f'Open positions: {len(open_ones)}')
for p in open_ones:
    print(f\"  contract={p.get('contractId')} netPos={p.get('netPos')}\")" 2>/dev/null

curl -s -H "Authorization: Bearer $TOKEN" "$BASE/fill/list" | python3 -c "
import sys, json
from datetime import datetime, timezone
d = json.load(sys.stdin)
today = datetime.now(timezone.utc).strftime('%Y-%m-%d')
fills = [f for f in d if f.get('timestamp','').startswith(today)]
print(f'Fills today: {len(fills)}')
for f in fills[-5:]:
    print(f\"  {f.get('timestamp')} {f.get('action')} qty={f.get('qty')} price={f.get('price')}\")" 2>/dev/null
echo ""

echo "=== Done ==="
