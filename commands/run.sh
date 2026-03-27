#!/bin/bash
# Trigger: v12 - use pre-obtained access token
echo "=== Tradovate Token Setup ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"

cd /root/MT5-PropFirm-Bot

python3 << 'PYEOF'
import requests, json, time, os

token = os.environ.get('TRADOVATE_ACCESS_TOKEN', '').strip()
print(f"Token length: {len(token)}")
print(f"Token starts: {token[:20]}...")
print(f"Token ends: ...{token[-10:]}")

if not token:
    print("ERROR: No token found!")
    exit(1)

# Test token on DEMO (where TradeDay lives)
base_url = "https://demo.tradovateapi.com/v1"
headers = {"Authorization": f"Bearer {token}"}

print("\n--- Testing token on DEMO ---")
try:
    resp = requests.get(f"{base_url}/account/list", headers=headers, timeout=10)
    if resp.status_code == 200:
        accounts = resp.json()
        print(f"SUCCESS! Found {len(accounts)} accounts:")
        for acc in accounts:
            print(f"  - {acc.get('name','?')} (id={acc.get('id','?')})")

        # Save token to config file
        token_data = {
            "access_token": token,
            "md_access_token": token,
            "expiry": time.time() + 86400,
            "environment": "demo",
            "organization": "TradeDay",
        }
        with open("configs/.tradovate_token.json", "w") as f:
            json.dump(token_data, f, indent=2)
        print("\nToken saved to configs/.tradovate_token.json")

        # Also save to .env
        env_lines = []
        if os.path.exists(".env"):
            with open(".env") as f:
                env_lines = [l for l in f.readlines() if not l.startswith("TRADOVATE_ACCESS_TOKEN")]
        env_lines.append(f"TRADOVATE_ACCESS_TOKEN={token}\n")
        with open(".env", "w") as f:
            f.writelines(env_lines)
        print("Token added to .env")

        # Get balance
        try:
            bal_resp = requests.post(f"{base_url}/cashBalance/getcashbalancesnapshot",
                                     headers=headers,
                                     json={"accountId": accounts[0]["id"]},
                                     timeout=10)
            bal = bal_resp.json()
            print(f"\nBalance: ${bal.get('totalCashValue', 'N/A')}")
        except:
            pass

        # Get positions
        try:
            pos_resp = requests.get(f"{base_url}/position/list", headers=headers, timeout=10)
            positions = pos_resp.json()
            print(f"Open positions: {len(positions)}")
        except:
            pass

    else:
        print(f"Failed: status={resp.status_code}")
        print(resp.text[:200])
except Exception as e:
    print(f"Error: {e}")

print("\nDone!")
PYEOF
