#!/bin/bash
# Trigger: setup v3 - output to log
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
echo ".env created with $(wc -l < .env) lines"
echo ""

# --- Step 2: Install Python dependencies ---
echo "--- Step 2: Installing dependencies ---"
pip3 install aiohttp websockets requests 2>&1 | tail -5
echo ""

# --- Step 3: Create directories ---
echo "--- Step 3: Creating directories ---"
mkdir -p logs configs status
echo "Directories ready"
echo ""

# --- Step 4: Test Tradovate connection ---
echo "--- Step 4: Testing Tradovate auth ---"
python3 -c "
import requests, uuid, json

url = 'https://demo.tradovateapi.com/v1/auth/accesstokenrequest'
payload = {
    'name': '${TRADOVATE_USER}',
    'password': '${TRADOVATE_PASS}',
    'appId': 'tradovate_trader(web)',
    'appVersion': '3.260220.0',
    'deviceId': str(uuid.uuid4()),
    'cid': 8,
    'sec': '',
    'organization': '',
}

print(f'Authenticating as: {payload[\"name\"]}')
resp = requests.post(url, json=payload, timeout=30)
data = resp.json()

if 'accessToken' in data:
    token = data['accessToken']
    md_token = data.get('mdAccessToken', token)
    print(f'SUCCESS! Got access token: {token[:20]}...')
    print(f'MD token: {md_token[:20]}...')

    # Save token
    import time
    token_data = {
        'access_token': token,
        'md_access_token': md_token,
        'expiry': time.time() + 86400,
        'saved_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
    }
    with open('configs/.tradovate_token.json', 'w') as f:
        json.dump(token_data, f, indent=2)
    print('Token saved to configs/.tradovate_token.json')

    # Test account list
    headers = {'Authorization': f'Bearer {token}'}
    acc_resp = requests.get('https://demo.tradovateapi.com/v1/account/list', headers=headers, timeout=10)
    accounts = acc_resp.json()
    print(f'Accounts found: {len(accounts)}')
    for acc in accounts:
        print(f'  - {acc.get(\"name\", \"?\")} (id={acc.get(\"id\", \"?\")})')

elif 'p-ticket' in data:
    p_captcha = data.get('p-captcha', False)
    if p_captcha:
        print('CAPTCHA REQUIRED!')
        print('Need to solve CAPTCHA once from browser.')
        print('Run: python3 get_token.py on VPS via VNC')
    else:
        print(f'Got p-ticket, waiting {data.get(\"p-time\", 15)}s...')
        import time
        time.sleep(data.get('p-time', 15))
        payload['p-ticket'] = data['p-ticket']
        resp2 = requests.post(url, json=payload, timeout=30)
        data2 = resp2.json()
        if 'accessToken' in data2:
            token = data2['accessToken']
            print(f'SUCCESS after wait! Token: {token[:20]}...')
            token_data = {
                'access_token': token,
                'md_access_token': data2.get('mdAccessToken', token),
                'expiry': time.time() + 86400,
                'saved_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
            }
            with open('configs/.tradovate_token.json', 'w') as f:
                json.dump(token_data, f, indent=2)
            print('Token saved!')
        else:
            print(f'Still failed after wait: {data2}')
else:
    print(f'Auth failed: {data}')
" 2>&1
echo ""

# --- Step 5: Install systemd service ---
echo "--- Step 5: Setting up systemd service ---"
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
echo "Service installed and enabled"
echo ""

# --- Step 6: Check existing processes ---
echo "--- Step 6: System status ---"
echo "Python version: $(python3 --version)"
echo "Disk: $(df -h / | tail -1 | awk '{print $4}') free"
echo "RAM: $(free -h | grep Mem | awk '{print $4}') free"
echo ""

# Don't start the bot yet - wait for confirmation
echo "--- Setup Complete ---"
echo "Bot is NOT started yet (waiting for confirmation)."
echo "To start: systemctl start futures-bot"
echo ""
echo "=== Setup Complete ==="
