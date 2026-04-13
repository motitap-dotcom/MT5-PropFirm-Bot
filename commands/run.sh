#!/bin/bash
# Trigger: v153 - inspect actual positions from Tradovate + risk manager state
cd /root/MT5-PropFirm-Bot
echo "=== v153 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot) ($(systemctl show futures-bot --property=SubState --value))"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Restarts: $(systemctl show futures-bot --property=NRestarts --value)"
echo ""

echo "=== STATUS.JSON ==="
cat status/status.json 2>/dev/null
echo ""

echo "=== Query Tradovate API directly for real positions ==="
PYTHONPATH=/root/MT5-PropFirm-Bot /usr/bin/python3 << 'PYEOF' 2>&1
import json, os, sys
from pathlib import Path

# Load token
token_path = Path("configs/.tradovate_token.json")
if not token_path.exists():
    print("NO TOKEN FILE")
    sys.exit(0)

token_data = json.loads(token_path.read_text())
token = token_data.get("accessToken") or token_data.get("access_token") or ""
expires = token_data.get("expirationTime") or token_data.get("expires") or ""
print(f"Token expires: {expires}")
print(f"Token present: {'yes' if token else 'no'}")

if not token:
    sys.exit(0)

import urllib.request
import urllib.error

base = "https://live.tradovateapi.com/v1"
headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

def get(path):
    req = urllib.request.Request(f"{base}{path}", headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return {"error": f"HTTP {e.code}: {e.read().decode()[:200]}"}
    except Exception as e:
        return {"error": str(e)}

print("\n--- /account/list ---")
accts = get("/account/list")
print(json.dumps(accts, indent=2)[:600])

print("\n--- /position/list ---")
positions = get("/position/list")
print(json.dumps(positions, indent=2)[:2000])

print("\n--- /order/list ---")
orders = get("/order/list")
if isinstance(orders, list):
    # Show only active orders
    active = [o for o in orders if o.get("ordStatus") in ("Working", "PendingNew", "Accepted")]
    print(f"Active orders: {len(active)}")
    print(json.dumps(active[:10], indent=2)[:2000])
else:
    print(json.dumps(orders, indent=2)[:1000])

print("\n--- /contract/list (first 5) ---")
contracts = get("/contract/list")
if isinstance(contracts, list):
    print(f"Total: {len(contracts)}")
    for c in contracts[:5]:
        print(f"  id={c.get('id')} name={c.get('name')}")
PYEOF

echo ""
echo "=== Risk manager + bot state from logs ==="
grep -E "Max positions|positions:|open_positions|Trade blocked|Signal.*blocked" logs/bot.log 2>/dev/null | tail -15
echo ""
echo "=== Last 20 bot.log lines ==="
tail -20 logs/bot.log
