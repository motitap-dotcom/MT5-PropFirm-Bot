#!/bin/bash
# Trigger: v154 - debug market data API
cd /root/MT5-PropFirm-Bot
echo "=== MARKET DATA DEBUG v154 $(date -u '+%Y-%m-%d %H:%M UTC') ==="

# Run Python diagnostic against Tradovate API
python3 << 'PYEOF'
import json, os, sys
sys.path.insert(0, '/root/MT5-PropFirm-Bot')

from pathlib import Path

# Load token
token_file = Path("configs/.tradovate_token.json")
if not token_file.exists():
    print("ERROR: No token file!")
    sys.exit(1)

token_data = json.loads(token_file.read_text())
access_token = token_data.get("access_token")
md_token = token_data.get("md_access_token", access_token)
print(f"Token loaded: {bool(access_token)}, MD token: {bool(md_token)}")

import requests

# Test 1: Verify account access
headers = {"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"}
r = requests.get("https://demo.tradovateapi.com/v1/account/list", headers=headers)
print(f"\nAccount API: {r.status_code}")
if r.status_code == 200:
    accounts = r.json()
    for a in accounts[:2]:
        print(f"  Account: {a.get('name')} id={a.get('id')}")

# Test 2: Search for contracts
print("\n--- Contract Search ---")
for sym in ["MESM6", "MES", "ESM6", "ES"]:
    r = requests.get(f"https://demo.tradovateapi.com/v1/contract/suggest?t={sym}&l=3", headers=headers)
    if r.status_code == 200:
        results = r.json()
        print(f"{sym}: {len(results)} results")
        for c in results[:2]:
            print(f"  -> {c.get('name')} id={c.get('id')} status={c.get('status')}")
    else:
        print(f"{sym}: HTTP {r.status_code}")

# Test 3: Get chart data with different symbol formats
print("\n--- Chart Data Test ---")
md_headers = {"Authorization": f"Bearer {md_token}", "Content-Type": "application/json"}
md_base = "https://md-demo.tradovateapi.com/v1"

for sym in ["MESM6", "ESM6", "MES"]:
    payload = {
        "symbol": sym,
        "chartDescription": {
            "underlyingType": "MinuteBar",
            "elementSize": 5,
            "elementSizeUnit": "UnderlyingUnits",
            "withHistogram": False,
        },
        "timeRange": {
            "asMuchAsElements": 5,
        },
    }
    r = requests.post(f"{md_base}/md/getChart", headers=md_headers, json=payload)
    if r.status_code == 200:
        data = r.json()
        bars = data.get("bars", [])
        print(f"{sym}: {r.status_code} | {len(bars)} bars | keys={list(data.keys())[:5]}")
        if bars:
            print(f"  Latest: {bars[-1]}")
        elif data:
            # Show raw response (truncated)
            raw = json.dumps(data)[:300]
            print(f"  Raw: {raw}")
    else:
        text = r.text[:200]
        print(f"{sym}: HTTP {r.status_code} | {text}")

# Test 4: Try with contract ID
print("\n--- Contract ID lookup ---")
r = requests.get(f"https://demo.tradovateapi.com/v1/contract/find?name=MESM6", headers=headers)
if r.status_code == 200:
    contract = r.json()
    print(f"MESM6 contract: {json.dumps(contract)[:300]}")
    cid = contract.get("id")
    if cid:
        # Try chart with contract ID
        payload["symbol"] = str(cid)
        r2 = requests.post(f"{md_base}/md/getChart", headers=md_headers, json=payload)
        if r2.status_code == 200:
            data2 = r2.json()
            bars2 = data2.get("bars", [])
            print(f"By ID ({cid}): {len(bars2)} bars")
            if bars2:
                print(f"  Latest: {bars2[-1]}")
else:
    print(f"Contract find: HTTP {r.status_code}")

PYEOF
