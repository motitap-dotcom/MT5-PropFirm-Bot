#!/bin/bash
# Trigger: v135 - Test different organization values
cd /root/MT5-PropFirm-Bot
source .env
echo "=== Auth Test v135 $(date -u '+%Y-%m-%d %H:%M UTC') ==="

python3 << PYEOF
import requests, json, base64, hmac, hashlib

username = "$TRADOVATE_USER"
password = "$TRADOVATE_PASS"

# Encrypt password
offset = len(username) % len(password)
rearranged = password[offset:] + password[:offset]
encrypted_pw = base64.b64encode(rearranged[::-1].encode()).decode()

url = "https://demo.tradovateapi.com/v1/auth/accesstokenrequest"

# Test different organization values
for org in ["", "tradeday", "TradeDay", "TRADEDAY"]:
    payload = {
        "name": username, "password": encrypted_pw,
        "appId": "tradovate_trader(web)", "appVersion": "3.260220.0",
        "deviceId": "futures-bot-td", "cid": 8, "sec": "", "chl": "",
        "organization": org,
    }
    fields = ["chl", "deviceId", "name", "password", "appId"]
    msg = "".join(str(payload.get(f, "")) for f in fields)
    payload["sec"] = hmac.new("1259-11e7-485a-aeae-9b6016579351".encode(), msg.encode(), hashlib.sha256).hexdigest()

    r = requests.post(url, json=payload, timeout=10)
    data = r.json()
    if "accessToken" in data:
        result = f"SUCCESS! account={data.get('accountSpec','?')}"
    elif "p-ticket" in data:
        result = f"p-ticket (captcha={data.get('p-captcha','')})"
    else:
        result = data.get("errorText", str(data))[:80]
    print(f'org="{org}": {result}')
PYEOF
