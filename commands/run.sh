#!/bin/bash
# Trigger: v107 - Check token details + try auth manually
cd /root/MT5-PropFirm-Bot
echo "=== Debug Auth v107 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"

# Check what account the token belongs to
echo ""
echo "=== Token details ==="
python3 -c "
import json
with open('configs/.tradovate_token.json') as f:
    t = json.load(f)
for k,v in t.items():
    if k == 'accessToken' or k == 'mdAccessToken':
        print(f'{k}: ...{str(v)[-20:]}')
    else:
        print(f'{k}: {v}')
" 2>&1

# Check .env username
echo ""
echo "=== .env user ==="
grep "TRADOVATE_USER" .env 2>/dev/null | head -1

# Try loading token and hitting API
echo ""
echo "=== Test token against API ==="
python3 << 'PYEOF'
import json, requests

try:
    with open("configs/.tradovate_token.json") as f:
        t = json.load(f)
    token = t.get("accessToken", "")

    # Try demo endpoint
    headers = {"Authorization": f"Bearer {token}"}
    r = requests.get("https://demo.tradovateapi.com/v1/account/list", headers=headers, timeout=10)
    print(f"Demo API status: {r.status_code}")
    if r.status_code == 200:
        accounts = r.json()
        for a in accounts[:3]:
            print(f"  Account: {a.get('name','')} id={a.get('id','')} active={a.get('active','')}")
    else:
        print(f"  Response: {r.text[:200]}")

    # Try renewal
    print("")
    print("=== Try renewal ===")
    r2 = requests.post("https://demo.tradovateapi.com/v1/auth/renewaccesstoken", headers=headers, timeout=10)
    print(f"Renewal status: {r2.status_code}")
    if r2.status_code == 200:
        data = r2.json()
        if "accessToken" in data:
            print("RENEWAL SUCCESS! New token obtained")
            # Save it
            with open("configs/.tradovate_token.json", "w") as f:
                json.dump(data, f, indent=2)
            print("Saved new token")
        else:
            print(f"Response: {data}")
    else:
        print(f"Response: {r2.text[:200]}")
except Exception as e:
    print(f"Error: {e}")
PYEOF
