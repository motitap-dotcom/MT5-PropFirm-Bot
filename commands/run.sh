#!/bin/bash
# Trigger: v118 - List all accounts + find TradeDay
cd /root/MT5-PropFirm-Bot

echo "=== List All Accounts v118 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"

python3 << 'PYEOF'
import json, requests

# Load renewed token
with open("configs/.tradovate_token.json") as f:
    t = json.load(f)
token = t.get("accessToken", "")

if not token:
    print("No token!")
    exit(1)

headers = {"Authorization": f"Bearer {token}"}

# List all accounts
print("=== All Accounts ===")
r = requests.get("https://demo.tradovateapi.com/v1/account/list", headers=headers, timeout=10)
if r.status_code == 200:
    for a in r.json():
        print(f"  id={a.get('id')} name={a.get('name')} active={a.get('active')} nickname={a.get('nickname','')}")
else:
    print(f"Error: {r.status_code} {r.text[:200]}")

# Cash balances
print("\n=== Cash Balances ===")
r2 = requests.get("https://demo.tradovateapi.com/v1/cashBalance/list", headers=headers, timeout=10)
if r2.status_code == 200:
    for b in r2.json():
        print(f"  accountId={b.get('accountId')} balance={b.get('amount',0)}")

# User info
print("\n=== User Info ===")
r3 = requests.get("https://demo.tradovateapi.com/v1/user/getUser", headers=headers, timeout=10)
if r3.status_code == 200:
    u = r3.json()
    print(f"  userId={u.get('id')} name={u.get('name')} email={u.get('email','')}")
    print(f"  professional={u.get('professional')} status={u.get('status')}")
PYEOF
