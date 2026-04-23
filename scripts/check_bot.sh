#!/bin/bash
echo "=== MD WebSocket verify ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

PID=$(systemctl show futures-bot --property=MainPID --value)
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
echo "Active: $(systemctl is-active futures-bot)"
echo "PID: $PID"
echo "CWD: $CWD"
echo "Uptime since: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""

echo "--- Does /opt have the new code? ---"
grep -c "MD WebSocket connect failed" /opt/futures_bot_stable/futures_bot/core/tradovate_client.py 2>/dev/null || echo "NOT FOUND"
grep -c "MD WebSocket connect failed" /root/MT5-PropFirm-Bot/futures_bot/core/tradovate_client.py 2>/dev/null || echo "root NOT FOUND"
echo ""

LOG="$CWD/logs/bot.log"
echo "--- Last 40 log lines from running instance ---"
tail -40 "$LOG" 2>/dev/null
echo ""

echo "--- Strategy + MD + signal lines from current uptime ---"
grep -iE "strategy\.|MD WebSocket|signal|entry|bars|md_ws|VWAP|ORB|Price=" "$LOG" 2>/dev/null | tail -20
echo ""

echo "--- Positions check ---"
TOKEN_FILE=$CWD/configs/.tradovate_token.json
[ ! -f "$TOKEN_FILE" ] && TOKEN_FILE=/root/MT5-PropFirm-Bot/configs/.tradovate_token.json
TOKEN=$(python3 -c "import json;print(json.load(open('$TOKEN_FILE')).get('access_token',''))" 2>/dev/null)
curl -s -H "Authorization: Bearer $TOKEN" "https://demo.tradovateapi.com/v1/position/list" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    open_ones=[p for p in d if p.get('netPos',0)!=0]
    print(f'Open positions: {len(open_ones)}')
    for p in open_ones:
        print(f\"  {p.get('contractId')} netPos={p.get('netPos')}\")
except: print('no data')
" 2>/dev/null
echo ""

echo "=== Done ==="
