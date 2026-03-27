#!/bin/bash
# Trigger: v10 - try different organization values
echo "=== Tradovate Auth - Organization Test ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"

cd /root/MT5-PropFirm-Bot

python3 << 'PYEOF'
import requests, uuid, json, time, os

user = os.environ.get('TRADOVATE_USER', '')
passwd = os.environ.get('TRADOVATE_PASS', '')
print(f"User: {user}, Pass length: {len(passwd)}")

# Try different organization values and both environments
orgs = ["", "tradeday", "trade-day", "TradeDay", "TRADEDAY"]
envs = [("LIVE", "https://live.tradovateapi.com/v1"), ("DEMO", "https://demo.tradovateapi.com/v1")]

for org in orgs:
    for env_name, base_url in envs:
        payload = {
            "name": user,
            "password": passwd,
            "appId": "tradovate_trader(web)",
            "appVersion": "3.260220.0",
            "deviceId": str(uuid.uuid4()),
            "cid": 8,
            "sec": "",
            "organization": org,
        }
        try:
            resp = requests.post(f"{base_url}/auth/accesstokenrequest", json=payload, timeout=15)
            data = resp.json()

            if "accessToken" in data:
                print(f"\nSUCCESS! org='{org}' env={env_name}")
                print(f"Token: {data['accessToken'][:30]}...")
                token_data = {
                    "access_token": data["accessToken"],
                    "md_access_token": data.get("mdAccessToken", data["accessToken"]),
                    "expiry": time.time() + 86400,
                    "environment": env_name.lower(),
                    "organization": org,
                }
                with open("configs/.tradovate_token.json", "w") as f:
                    json.dump(token_data, f, indent=2)

                headers = {"Authorization": f"Bearer {data['accessToken']}"}
                acc = requests.get(f"{base_url}/account/list", headers=headers, timeout=10).json()
                print(f"Accounts: {len(acc)}")
                for a in acc:
                    print(f"  {a.get('name','?')} id={a.get('id','?')}")
                exit(0)
            elif "p-ticket" in data:
                print(f"org='{org}' {env_name}: p-ticket (captcha={data.get('p-captcha')})")
                # This means credentials are CORRECT but need CAPTCHA
                if not data.get("p-captcha"):
                    print(f"  Waiting {data.get('p-time',15)}s...")
                    time.sleep(data.get("p-time", 15))
                    payload["p-ticket"] = data["p-ticket"]
                    r2 = requests.post(f"{base_url}/auth/accesstokenrequest", json=payload, timeout=30)
                    d2 = r2.json()
                    if "accessToken" in d2:
                        print(f"  SUCCESS after wait! org='{org}' {env_name}")
                        exit(0)
                else:
                    print(f"  CAPTCHA needed! But credentials are CORRECT with org='{org}' on {env_name}")
                    exit(0)
            else:
                err = data.get("errorText", "")[:60]
                print(f"org='{org}' {env_name}: {err}")
        except Exception as e:
            print(f"org='{org}' {env_name}: ERROR {e}")

print("\nAll combinations failed")
PYEOF
