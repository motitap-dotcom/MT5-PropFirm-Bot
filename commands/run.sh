#!/bin/bash
# Trigger: v91 - Test auth with aiohttp (available in venv)
cd /root/MT5-PropFirm-Bot

echo "=== AUTH TEST ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

source .env 2>/dev/null
PY="python3"
[ -d "venv" ] && PY="venv/bin/python3"

# Install requests in venv
$PY -m pip install requests -q 2>&1 | tail -2

$PY << 'PYEOF'
import os, json, base64, hashlib, hmac as hmac_mod, uuid, requests

username = os.environ.get("TRADOVATE_USER", "")
password = os.environ.get("TRADOVATE_PASS", "")
print(f"Username: {username}")
print(f"Password length: {len(password)}")
print()

HMAC_KEY = "1259-11e7-485a-aeae-9b6016579351"
HMAC_FIELDS = ["chl", "deviceId", "name", "password", "appId"]
device_id = str(uuid.uuid4())

def encrypt_pw(name, pw):
    offset = len(name) % len(pw)
    rearranged = pw[offset:] + pw[:offset]
    reversed_pw = rearranged[::-1]
    return base64.b64encode(reversed_pw.encode()).decode()

def compute_hmac(payload):
    message = "".join(str(payload.get(f, "")) for f in HMAC_FIELDS)
    return hmac_mod.new(HMAC_KEY.encode(), message.encode(), hashlib.sha256).hexdigest()

# Test 1: Encrypted password + HMAC
enc_pw = encrypt_pw(username, password)
payload1 = {
    "name": username, "password": enc_pw,
    "appId": "tradovate_trader(web)", "appVersion": "3.260220.0",
    "deviceId": device_id, "cid": 8, "sec": "", "chl": "", "organization": "",
}
payload1["sec"] = compute_hmac(payload1)

print("--- Test 1: Encrypted password + HMAC ---")
for url_name, url in [("demo", "https://demo.tradovateapi.com/v1/auth/accesstokenrequest"),
                        ("live", "https://live.tradovateapi.com/v1/auth/accesstokenrequest")]:
    try:
        resp = requests.post(url, json=payload1, timeout=15)
        data = resp.json()
        if "accessToken" in data:
            print(f"  {url_name}: SUCCESS! Token: {data['accessToken'][:20]}...")
            # Save token for the bot
            token_data = {
                "access_token": data["accessToken"],
                "md_access_token": data.get("mdAccessToken", data["accessToken"]),
                "expiry": __import__('time').time() + 86400,
            }
            with open("configs/.tradovate_token.json", "w") as f:
                json.dump(token_data, f, indent=2)
            print(f"  Token saved to configs/.tradovate_token.json")
        elif "p-ticket" in data:
            print(f"  {url_name}: p-ticket (captcha={data.get('p-captcha', False)})")
        else:
            print(f"  {url_name}: {data.get('errorText', str(data)[:100])}")
    except Exception as e:
        print(f"  {url_name}: ERROR: {e}")

print()

# Test 2: Plain password (old method)
payload2 = {
    "name": username, "password": password,
    "appId": "tradovate_trader(web)", "appVersion": "3.260220.0",
    "deviceId": device_id, "cid": 8, "sec": "", "organization": "",
}

print("--- Test 2: Plain password ---")
for url_name, url in [("demo", "https://demo.tradovateapi.com/v1/auth/accesstokenrequest"),
                        ("live", "https://live.tradovateapi.com/v1/auth/accesstokenrequest")]:
    try:
        resp = requests.post(url, json=payload2, timeout=15)
        data = resp.json()
        if "accessToken" in data:
            print(f"  {url_name}: SUCCESS! Token: {data['accessToken'][:20]}...")
        elif "p-ticket" in data:
            print(f"  {url_name}: p-ticket (captcha={data.get('p-captcha', False)})")
        else:
            print(f"  {url_name}: {data.get('errorText', str(data)[:100])}")
    except Exception as e:
        print(f"  {url_name}: ERROR: {e}")

PYEOF

echo ""
echo "=== END ==="
