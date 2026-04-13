#!/bin/bash
# Trigger: v154 - query DEMO Tradovate + find orphan positions
cd /root/MT5-PropFirm-Bot
echo "=== v154 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot) ($(systemctl show futures-bot --property=SubState --value))"
echo ""

echo "=== Query DEMO Tradovate API ==="
PYTHONPATH=/root/MT5-PropFirm-Bot /usr/bin/python3 << 'PYEOF' 2>&1
import json, sys
from pathlib import Path

token_data = json.loads(Path("configs/.tradovate_token.json").read_text())
token = token_data.get("accessToken") or token_data.get("access_token") or ""
print(f"Token keys: {list(token_data.keys())}")
print(f"Token first 20 chars: {token[:20]}...")

import urllib.request, urllib.error
base = "https://demo.tradovateapi.com/v1"
headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

def get(path):
    req = urllib.request.Request(f"{base}{path}", headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return {"error": f"HTTP {e.code}: {e.read().decode()[:300]}"}
    except Exception as e:
        return {"error": str(e)}

print("\n--- DEMO /account/list ---")
accts = get("/account/list")
print(json.dumps(accts, indent=2)[:800])

print("\n--- DEMO /position/list ---")
positions = get("/position/list")
print(json.dumps(positions, indent=2)[:3000])

if isinstance(positions, list):
    open_pos = [p for p in positions if p.get("netPos", 0) != 0]
    print(f"\n>>> OPEN POSITIONS (netPos != 0): {len(open_pos)}")
    for p in open_pos:
        print(f"  id={p.get('id')} contract={p.get('contractId')} netPos={p.get('netPos')} avgPrice={p.get('netPrice')}")

print("\n--- DEMO /order/list (active only) ---")
orders = get("/order/list")
if isinstance(orders, list):
    active = [o for o in orders if o.get("ordStatus") in ("Working", "PendingNew", "Accepted", "PendingReplace")]
    print(f"Active: {len(active)}")
    for o in active[:10]:
        print(f"  id={o.get('id')} action={o.get('action')} contract={o.get('contractId')} status={o.get('ordStatus')}")

print("\n--- DEMO /fill/list (last 5) ---")
fills = get("/fill/list")
if isinstance(fills, list):
    print(f"Total fills: {len(fills)}")
    for f in fills[-5:]:
        print(f"  {f.get('timestamp')} action={f.get('action')} qty={f.get('qty')} price={f.get('price')}")
PYEOF

echo ""
echo "=== Position sync messages since 14:18 ==="
awk '/2026-04-13 14:(1[8-9]|[2-5][0-9])/' logs/bot.log 2>/dev/null | grep -E "Position sync|get_positions|Flatten|flatten" | tail -20
echo ""
echo "=== Recent errors since 14:18 (non-status) ==="
awk '/2026-04-13 14:(1[8-9]|[2-5][0-9])/' logs/bot.log 2>/dev/null | grep -iE "error|exception" | grep -v "Failed to write status" | tail -15
