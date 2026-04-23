#!/bin/bash
echo "=== Account Balance Check ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

TOKEN_FILE=/root/MT5-PropFirm-Bot/configs/.tradovate_token.json
if [ ! -f "$TOKEN_FILE" ]; then
  echo "Token file missing"
  exit 1
fi

TOKEN=$(python3 -c "import json;print(json.load(open('$TOKEN_FILE'))['accessToken'])" 2>/dev/null)
if [ -z "$TOKEN" ]; then
  echo "Could not parse token"
  exit 1
fi

# Determine endpoint (DEMO vs LIVE)
LIVE="false"
grep -q '"live": true' /root/MT5-PropFirm-Bot/configs/bot_config.json 2>/dev/null && LIVE="true"
if [ "$LIVE" = "true" ]; then
  BASE="https://live.tradovateapi.com/v1"
else
  BASE="https://demo.tradovateapi.com/v1"
fi
echo "Environment: $([ "$LIVE" = "true" ] && echo LIVE || echo DEMO)"
echo "API: $BASE"
echo ""

echo "--- Account list ---"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/account/list" | python3 -m json.tool 2>&1 | head -40
echo ""

echo "--- Cash balance snapshot ---"
ACC_ID=45373493
curl -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -X POST "$BASE/cashBalance/getCashBalanceSnapshot" \
  -d "{\"accountId\": $ACC_ID}" | python3 -m json.tool 2>&1 | head -40
echo ""

echo "--- Positions ---"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/position/list" | python3 -m json.tool 2>&1 | head -40
echo ""

echo "--- Fill history (recent) ---"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/fill/list" | python3 -m json.tool 2>&1 | head -40
echo ""

echo "=== Done ==="
