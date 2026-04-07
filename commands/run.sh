#!/bin/bash
# Trigger: v116 - Direct auth test with full response
cd /root/MT5-PropFirm-Bot
source .env
echo "=== Direct Auth Test v116 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"

python3 << 'PYEOF'
import requests, json, os, base64, hmac, hashlib, time

username = os.environ.get("TRADOVATE_USER", "")
password = os.environ.get("TRADOVATE_PASS", "")
print(f"User: {username}")

# Encrypt
offset = len(username) % len(password)
rearranged = password[offset:] + password[:offset]
encrypted_pw = base64.b64encode(rearranged[::-1].encode()).decode()

# Build payload exactly like Tradovate-Bot
payload = {
    "name": username,
    "password": encrypted_pw,
    "appId": "tradovate_trader(web)",
    "appVersion": "3.260220.0",
    "deviceId": "futures-bot-td",
    "cid": 8,
    "sec": "",
    "chl": "",
    "organization": "",
}

# HMAC into sec
fields = ["chl", "deviceId", "name", "password", "appId"]
msg = "".join(str(payload.get(f, "")) for f in fields)
payload["sec"] = hmac.new(
    "1259-11e7-485a-aeae-9b6016579351".encode(),
    msg.encode(), hashlib.sha256
).hexdigest()

print(f"\nPayload keys: {list(payload.keys())}")
print(f"sec length: {len(payload['sec'])}")

# Try demo
url = "https://demo.tradovateapi.com/v1/auth/accesstokenrequest"
print(f"\nPOST {url}")
r = requests.post(url, json=payload, timeout=15)
print(f"Status: {r.status_code}")
data = r.json()
print(f"Response keys: {list(data.keys())}")

if "accessToken" in data:
    print(f"\nSUCCESS!")
    print(f"Account: {data.get('accountSpec')}")
    with open("configs/.tradovate_token.json", "w") as f:
        json.dump(data, f, indent=2)
    print("Token saved!")
elif "p-ticket" in data:
    print(f"\np-ticket received!")
    print(f"p-captcha: {data.get('p-captcha', 'NOT SET')}")
    print(f"p-time: {data.get('p-time', 'NOT SET')}")
    if not data.get("p-captcha", False):
        wait = data.get("p-time", 15)
        print(f"No captcha needed! Waiting {wait}s...")
        time.sleep(wait + 1)
        payload["p-ticket"] = data["p-ticket"]
        r2 = requests.post(url, json=payload, timeout=15)
        data2 = r2.json()
        print(f"Retry keys: {list(data2.keys())}")
        if "accessToken" in data2:
            print("SUCCESS after p-ticket!")
            print(f"Account: {data2.get('accountSpec')}")
            with open("configs/.tradovate_token.json", "w") as f:
                json.dump(data2, f, indent=2)
            print("Token saved!")
        else:
            print(f"Failed: {json.dumps(data2)[:300]}")
    else:
        print("CAPTCHA IS REQUIRED (p-captcha=true)")
else:
    print(f"Error: {data.get('errorText', json.dumps(data)[:300])}")
PYEOF
