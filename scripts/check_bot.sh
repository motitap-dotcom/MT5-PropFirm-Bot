#!/bin/bash
echo "=== Account Balance Check ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

TOKEN_FILE=/root/MT5-PropFirm-Bot/configs/.tradovate_token.json
if [ ! -f "$TOKEN_FILE" ]; then
  echo "Token file missing"
  exit 1
fi

TOKEN=$(python3 -c "import json;print(json.load(open('$TOKEN_FILE')).get('access_token',''))" 2>/dev/null)
if [ -z "$TOKEN" ]; then
  echo "Could not parse token. File contents:"
  cat "$TOKEN_FILE" | head -c 200
  echo ""
  exit 1
fi

BASE="https://demo.tradovateapi.com/v1"
ACC_ID=45373493
echo "API: $BASE  Account: $ACC_ID"
echo ""

echo "--- /account/list ---"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/account/list" | python3 -m json.tool 2>&1 | head -30
echo ""

echo "--- Cash balance snapshot ---"
curl -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -X POST "$BASE/cashBalance/getCashBalanceSnapshot" \
  -d "{\"accountId\": $ACC_ID}" | python3 -m json.tool 2>&1 | head -40
echo ""

echo "--- Positions ---"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/position/list" | python3 -m json.tool 2>&1 | head -40
echo ""

echo "--- Recent fills (trade history) ---"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/fill/list" | python3 -m json.tool 2>&1 | head -60
echo ""

echo "=== Done ==="
