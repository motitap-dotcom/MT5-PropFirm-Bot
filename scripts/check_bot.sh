#!/bin/bash
echo "=== Market data (/md/getChart) test ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

TOKEN_FILE=/root/MT5-PropFirm-Bot/configs/.tradovate_token.json
[ ! -f "$TOKEN_FILE" ] && TOKEN_FILE=/opt/futures_bot_stable/configs/.tradovate_token.json

TOKEN=$(python3 -c "import json;d=json.load(open('$TOKEN_FILE'));print(d.get('md_access_token') or d.get('access_token',''))" 2>/dev/null)
if [ -z "$TOKEN" ]; then
  echo "Could not parse token"
  exit 1
fi
echo "Token present (first 20 chars): ${TOKEN:0:20}..."
echo ""

echo "--- Test /md/getChart directly ---"
curl -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -X POST "https://md-demo.tradovateapi.com/v1/md/getChart" \
  -d '{
    "symbol": "MESM6",
    "chartDescription": {
      "underlyingType": "MinuteBar",
      "elementSize": 5,
      "elementSizeUnit": "UnderlyingUnits",
      "withHistogram": false
    },
    "timeRange": {
      "asMuchAsElements": 5
    }
  }' | python3 -m json.tool 2>&1 | head -50
echo ""

echo "--- Test also /md/getChart on main API ---"
curl -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -X POST "https://demo.tradovateapi.com/v1/md/getChart" \
  -d '{
    "symbol": "MESM6",
    "chartDescription": {
      "underlyingType": "MinuteBar",
      "elementSize": 5,
      "elementSizeUnit": "UnderlyingUnits",
      "withHistogram": false
    },
    "timeRange": {
      "asMuchAsElements": 5
    }
  }' | python3 -m json.tool 2>&1 | head -30
echo ""

echo "--- Network connectivity to MD hosts ---"
curl -s -o /dev/null -w "md-demo REST: %{http_code} (%{time_total}s)\n" https://md-demo.tradovateapi.com/v1
curl -sI https://md-demo.tradovateapi.com/ 2>&1 | head -3
echo ""

echo "--- Check bot's current connections (to see if md is connected) ---"
PID=$(systemctl show futures-bot --property=MainPID --value)
echo "Bot PID: $PID"
[ -n "$PID" ] && [ "$PID" != "0" ] && {
  ss -tanp 2>/dev/null | grep "pid=$PID" | head -10
  echo "---"
  ls -la /proc/$PID/fd/ 2>/dev/null | grep socket | head -5
}
echo ""

echo "=== Done ==="
