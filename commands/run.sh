#!/bin/bash
# Trigger: setup v4 - fix pip + try both demo and live
echo "=== TradeDay Futures Bot - Full Setup ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

cd /root/MT5-PropFirm-Bot || { echo "FATAL: /root/MT5-PropFirm-Bot not found"; exit 1; }

# --- Step 1: Create .env with secrets ---
echo "--- Step 1: Setting up .env ---"
cat > /root/MT5-PropFirm-Bot/.env << ENVEOF
TRADOVATE_USER=${TRADOVATE_USER}
TRADOVATE_PASS=${TRADOVATE_PASS}
TELEGRAM_TOKEN=${TELEGRAM_TOKEN}
TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
ENVEOF
echo ".env created"
echo ""

# --- Step 2: Install Python dependencies ---
echo "--- Step 2: Installing dependencies ---"
pip3 install --break-system-packages aiohttp websockets requests 2>&1 | tail -3
echo ""

# --- Step 3: Test Tradovate auth (try BOTH demo and live) ---
echo "--- Step 3: Testing Tradovate auth ---"
python3 << 'PYEOF'
import requests, uuid, json, time, os

user = os.environ.get('TRADOVATE_USER', '')
passwd = os.environ.get('TRADOVATE_PASS', '')
print(f"Username: {user}")

for env_name, base_url in [("DEMO", "https://demo.tradovateapi.com/v1"), ("LIVE", "https://live.tradovateapi.com/v1")]:
    print(f"\n--- Trying {env_name}: {base_url} ---")
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
        print(f"Response: {json.dumps(data)[:200]}")

        if "accessToken" in data:
            print(f"SUCCESS on {env_name}!")
            token_data = {
                "access_token": data["accessToken"],
                "md_access_token": data.get("mdAccessToken", data["accessToken"]),
                "expiry": time.time() + 86400,
                "saved_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "environment": env_name.lower(),
            }
            with open("configs/.tradovate_token.json", "w") as f:
                json.dump(token_data, f, indent=2)
            print("Token saved!")

            # Test account list
            headers = {"Authorization": f"Bearer {data['accessToken']}"}
            acc_resp = requests.get(f"{base_url}/account/list", headers=headers, timeout=10)
            accounts = acc_resp.json()
            print(f"Accounts: {len(accounts)}")
            for acc in accounts:
                print(f"  - {acc.get('name', '?')} (id={acc.get('id', '?')})")
            break

        elif "p-ticket" in data:
            p_captcha = data.get("p-captcha", False)
            if p_captcha:
                print(f"CAPTCHA required on {env_name}!")
                print("Need to solve CAPTCHA once via VNC/browser")
            else:
                print(f"Waiting {data.get('p-time', 15)}s...")
                time.sleep(data.get("p-time", 15))
                payload["p-ticket"] = data["p-ticket"]
                resp2 = requests.post(f"{base_url}/auth/accesstokenrequest", json=payload, timeout=30)
                data2 = resp2.json()
                print(f"Retry response: {json.dumps(data2)[:200]}")
                if "accessToken" in data2:
                    print(f"SUCCESS on {env_name} after wait!")
                    break
        else:
            print(f"Failed on {env_name}: {data.get('errorText', str(data)[:100])}")

    except Exception as e:
        print(f"Error on {env_name}: {e}")

PYEOF
echo ""

# --- Step 4: Setup systemd service ---
echo "--- Step 4: systemd service ---"
cat > /etc/systemd/system/futures-bot.service << 'SERVICEEOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=/usr/bin/python3 -m futures_bot.bot
Restart=on-failure
RestartSec=30
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SERVICEEOF
systemctl daemon-reload
systemctl enable futures-bot
echo "Service ready"
echo ""

echo "=== Setup Complete ==="
