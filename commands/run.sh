#!/bin/bash
# Trigger: v110 - Try to get TradeDay token with encrypted password
cd /root/MT5-PropFirm-Bot

echo "=== Get TradeDay Token v110 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"

# Load credentials from .env
source .env

echo "User: $TRADOVATE_USER"

python3 << 'PYEOF'
import requests, json, os, base64, hmac, hashlib

username = os.environ.get("TRADOVATE_USER", "")
password = os.environ.get("TRADOVATE_PASS", "")

if not username or not password:
    print("ERROR: TRADOVATE_USER or TRADOVATE_PASS not set in .env")
    exit(1)

print(f"Authenticating as: {username}")

# Encrypt password (from working Tradovate-Bot)
offset = len(username) % len(password)
rearranged = password[offset:] + password[:offset]
reversed_pw = rearranged[::-1]
encrypted_pw = base64.b64encode(reversed_pw.encode()).decode()

# Build payload
payload = {
    "name": username,
    "password": encrypted_pw,
    "appId": "tradovate_trader(web)",
    "appVersion": "3.260220.0",
    "deviceId": "futures-bot-tradeday",
    "cid": 8,
    "sec": "",
}

# HMAC
hmac_key = "1259-11e7-485a-aeae-9b6016579351"
fields = ["chl", "deviceId", "name", "password", "appId"]
msg = "".join(str(payload.get(f, "")) for f in fields)
payload["hmac"] = hmac.new(hmac_key.encode(), msg.encode(), hashlib.sha256).hexdigest()

# Try demo endpoint
print("\n=== Trying demo endpoint ===")
try:
    r = requests.post("https://demo.tradovateapi.com/v1/auth/accesstokenrequest",
                       json=payload, timeout=15)
    print(f"Status: {r.status_code}")
    data = r.json()

    if "accessToken" in data:
        print("SUCCESS! Got token!")
        print(f"Account: {data.get('accountSpec', '?')}")
        print(f"Expires: {data.get('expirationTime', '?')}")
        # Save token
        with open("configs/.tradovate_token.json", "w") as f:
            json.dump(data, f, indent=2)
        print("Token saved to configs/.tradovate_token.json")
    elif "p-ticket" in data:
        p_captcha = data.get("p-captcha", False)
        p_time = data.get("p-time", 0)
        if p_captcha:
            print(f"CAPTCHA REQUIRED (p-captcha=true)")
            print("Need to solve CAPTCHA manually")
        else:
            print(f"P-TICKET received (no captcha). Waiting {p_time}s and retrying...")
            import time
            time.sleep(p_time + 1)
            payload["p-ticket"] = data["p-ticket"]
            r2 = requests.post("https://demo.tradovateapi.com/v1/auth/accesstokenrequest",
                               json=payload, timeout=15)
            data2 = r2.json()
            if "accessToken" in data2:
                print("SUCCESS after p-ticket wait!")
                print(f"Account: {data2.get('accountSpec', '?')}")
                with open("configs/.tradovate_token.json", "w") as f:
                    json.dump(data2, f, indent=2)
                print("Token saved!")
            else:
                print(f"Still failed: {json.dumps(data2)[:300]}")
    else:
        print(f"Response: {json.dumps(data)[:500]}")
except Exception as e:
    print(f"Error: {e}")

# Also try live endpoint
print("\n=== Trying live endpoint ===")
try:
    r = requests.post("https://live.tradovateapi.com/v1/auth/accesstokenrequest",
                       json=payload, timeout=15)
    print(f"Status: {r.status_code}")
    data = r.json()
    if "accessToken" in data:
        print("SUCCESS on live!")
        print(f"Account: {data.get('accountSpec', '?')}")
    elif "p-ticket" in data:
        print(f"P-TICKET (captcha={data.get('p-captcha', '?')})")
    else:
        print(f"Response: {json.dumps(data)[:300]}")
except Exception as e:
    print(f"Error: {e}")
PYEOF
