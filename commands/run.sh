#!/bin/bash
# Trigger: setup v6 - env vars via job-level env
echo "=== TradeDay Futures Bot - Setup ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

cd /root/MT5-PropFirm-Bot

# --- Step 1: Write .env directly using Python to avoid shell escaping ---
echo "--- Step 1: Creating .env ---"
python3 -c "
import os, sys
# Get from env vars passed by GitHub Actions
user = os.environ.get('TRADOVATE_USER', '')
passwd = os.environ.get('TRADOVATE_PASS', '')
tg_token = os.environ.get('TELEGRAM_TOKEN', '')
tg_chat = os.environ.get('TELEGRAM_CHAT_ID', '')

# Write .env file
with open('/root/MT5-PropFirm-Bot/.env', 'w') as f:
    f.write(f'TRADOVATE_USER={user}\n')
    f.write(f'TRADOVATE_PASS={passwd}\n')
    f.write(f'TELEGRAM_TOKEN={tg_token}\n')
    f.write(f'TELEGRAM_CHAT_ID={tg_chat}\n')
print(f'.env created (user={user}, pass_len={len(passwd)})')
"
echo ""

# --- Step 2: Test Tradovate auth using .env ---
echo "--- Step 2: Testing Tradovate auth ---"
python3 << 'PYEOF'
import requests, uuid, json, time

# Read credentials from .env file directly
creds = {}
with open("/root/MT5-PropFirm-Bot/.env") as f:
    for line in f:
        line = line.strip()
        if "=" in line and not line.startswith("#"):
            key, val = line.split("=", 1)
            creds[key] = val

user = creds.get("TRADOVATE_USER", "")
passwd = creds.get("TRADOVATE_PASS", "")
print(f"Username: {user}")
print(f"Password length: {len(passwd)}, last char: '{passwd[-1] if passwd else '?'}'")

for env_name, base_url in [("LIVE", "https://live.tradovateapi.com/v1"), ("DEMO", "https://demo.tradovateapi.com/v1")]:
    print(f"\n--- Trying {env_name} ---")
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
            print("Token saved!")

            headers = {"Authorization": f"Bearer {data['accessToken']}"}
            acc_resp = requests.get(f"{base_url}/account/list", headers=headers, timeout=10)
            accounts = acc_resp.json()
            print(f"Accounts: {len(accounts)}")
            for acc in accounts:
                print(f"  - {acc.get('name', '?')} (id={acc.get('id', '?')})")
            break
        elif "p-ticket" in data:
            print(f"CAPTCHA/wait required on {env_name}")
            p_captcha = data.get("p-captcha", False)
            if not p_captcha:
                print(f"Waiting {data.get('p-time', 15)}s...")
                time.sleep(data.get("p-time", 15))
                payload["p-ticket"] = data["p-ticket"]
                resp2 = requests.post(f"{base_url}/auth/accesstokenrequest", json=payload, timeout=30)
                data2 = resp2.json()
                if "accessToken" in data2:
                    print(f"SUCCESS on {env_name} after wait!")
                    break
                else:
                    print(f"Still failed: {json.dumps(data2)[:150]}")
            else:
                print("CAPTCHA needed - solve via VNC/browser on VPS")
        else:
            print(f"Failed: {data.get('errorText', str(data)[:150])}")
    except Exception as e:
        print(f"Error: {e}")
PYEOF
echo ""

echo "=== Done ==="
