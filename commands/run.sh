#!/bin/bash
# Trigger: v125 - Verify token + list accounts + restart bot
cd /root/MT5-PropFirm-Bot
echo "=== Verify & Go v125 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"

echo ""
echo "=== Token ==="
python3 << 'PYEOF'
import json, requests
from datetime import datetime, timezone

with open("configs/.tradovate_token.json") as f:
    t = json.load(f)

token = t.get("accessToken", "")
print(f"Expires: {t.get('expirationTime','?')}")

headers = {"Authorization": f"Bearer {token}"}
r = requests.get("https://demo.tradovateapi.com/v1/account/list", headers=headers, timeout=10)
if r.status_code == 200:
    accounts = r.json()
    print(f"\nAccounts ({len(accounts)}):")
    for a in accounts:
        print(f"  {a.get('name','')} id={a.get('id','')} active={a.get('active','')}")

    # Get balance
    r2 = requests.get("https://demo.tradovateapi.com/v1/cashBalance/list", headers=headers, timeout=10)
    if r2.status_code == 200:
        for b in r2.json():
            print(f"  Balance for {b.get('accountId')}: ${b.get('amount',0):,.2f}")
else:
    print(f"API error: {r.status_code} {r.text[:200]}")
PYEOF

echo ""
echo "=== Service ==="
echo "Status: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value 2>/dev/null)"
