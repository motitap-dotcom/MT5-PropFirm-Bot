#!/bin/bash
# Trigger: v9 - password without !
echo "=== Tradovate Auth Test ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"

cd /root/MT5-PropFirm-Bot

python3 << 'PYEOF'
import requests, uuid, json, time, os

user = os.environ.get('TRADOVATE_USER', '')
passwd = os.environ.get('TRADOVATE_PASS', '')
print(f"User: {user}, Pass length: {len(passwd)}")

for env_name, base_url in [("LIVE", "https://live.tradovateapi.com/v1"), ("DEMO", "https://demo.tradovateapi.com/v1")]:
    print(f"\n--- {env_name} ---")
    payload = {
        "name": user,
        "password": passwd,
        "appId": "tradovate_trader(web)",
        "appVersion": "3.260220.0",
        "deviceId": str(uuid.uuid4()),
        "cid": 8,
        "sec": "",
        "organization": "",
    }
    try:
        resp = requests.post(f"{base_url}/auth/accesstokenrequest", json=payload, timeout=30)
        data = resp.json()
        print(f"Response keys: {list(data.keys())}")

        if "accessToken" in data:
            print(f"SUCCESS on {env_name}!")
            token_data = {
                "access_token": data["accessToken"],
                "md_access_token": data.get("mdAccessToken", data["accessToken"]),
                "expiry": time.time() + 86400,
                "environment": env_name.lower(),
            }
            with open("configs/.tradovate_token.json", "w") as f:
                json.dump(token_data, f, indent=2)

            headers = {"Authorization": f"Bearer {data['accessToken']}"}
            acc = requests.get(f"{base_url}/account/list", headers=headers, timeout=10).json()
            print(f"Accounts: {len(acc)}")
            for a in acc:
                print(f"  {a.get('name','?')} id={a.get('id','?')}")
            break
        elif "p-ticket" in data:
            print(f"p-ticket received, p-captcha={data.get('p-captcha')}")
            if not data.get("p-captcha"):
                print(f"Waiting {data.get('p-time',15)}s...")
                time.sleep(data.get("p-time", 15))
                payload["p-ticket"] = data["p-ticket"]
                r2 = requests.post(f"{base_url}/auth/accesstokenrequest", json=payload, timeout=30)
                d2 = r2.json()
                if "accessToken" in d2:
                    print(f"SUCCESS after wait!")
                    with open("configs/.tradovate_token.json", "w") as f:
                        json.dump({"access_token": d2["accessToken"], "md_access_token": d2.get("mdAccessToken",""), "expiry": time.time()+86400, "environment": env_name.lower()}, f)
                    break
                print(f"Still failed: {list(d2.keys())}")
            else:
                print("CAPTCHA needed - use VNC browser")
        else:
            print(f"Error: {data.get('errorText','unknown')}")
    except Exception as e:
        print(f"Exception: {e}")

print("\nDone")
PYEOF
