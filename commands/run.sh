#!/bin/bash
# Trigger: v41 - diagnose credentials
echo "=== Credential Diagnostics ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot

echo "--- .env contents (masked) ---"
python3 << 'PYEOF'
import os

# Check .env file
if os.path.exists('.env'):
    with open('.env') as f:
        for line in f:
            line = line.strip()
            if '=' in line and not line.startswith('#'):
                key, val = line.split('=', 1)
                if len(val) > 4:
                    masked = val[:2] + '*' * (len(val)-4) + val[-2:]
                else:
                    masked = '***'
                print(f"  {key} = {masked} (len={len(val)})")
else:
    print("  .env NOT FOUND!")

# Check systemd env override
print("\n--- Systemd env override (masked) ---")
conf = '/etc/systemd/system/futures-bot.service.d/env.conf'
if os.path.exists(conf):
    with open(conf) as f:
        for line in f:
            line = line.strip()
            if 'Environment=' in line:
                # Format: Environment="KEY=VALUE"
                inner = line.split('Environment=')[1].strip('"')
                if '=' in inner:
                    key, val = inner.split('=', 1)
                    val = val.strip('"')
                    if len(val) > 4:
                        masked = val[:2] + '*' * (len(val)-4) + val[-2:]
                    else:
                        masked = '***'
                    print(f"  {key} = {masked} (len={len(val)})")
else:
    print("  No systemd override file")

# Check what the bot actually sees
print("\n--- Environment vars (masked) ---")
for key in ['TRADOVATE_USER', 'TRADOVATE_PASS', 'TRADOVATE_ACCESS_TOKEN']:
    val = os.environ.get(key, '')
    if len(val) > 4:
        masked = val[:2] + '*' * (len(val)-4) + val[-2:]
    elif val:
        masked = '***'
    else:
        masked = 'EMPTY'
    print(f"  {key} = {masked} (len={len(val)})")

# Try auth directly to see exact error
print("\n--- Direct auth test ---")
import json
user = None
passwd = None
if os.path.exists('.env'):
    with open('.env') as f:
        for line in f:
            if line.startswith('TRADOVATE_USER='):
                user = line.split('=',1)[1].strip()
            elif line.startswith('TRADOVATE_PASS='):
                passwd = line.split('=',1)[1].strip()

if user and passwd:
    print(f"  User: {user}")
    print(f"  Pass length: {len(passwd)}, has special chars: {not passwd.isalnum()}")

    import urllib.request, urllib.error
    payload = json.dumps({
        "name": user,
        "password": passwd,
        "appId": "tradovate_trader(web)",
        "appVersion": "3.260220.0",
        "deviceId": "bot-diag",
        "cid": 8,
        "sec": "",
        "organization": "TradeDay"
    }).encode()
    req = urllib.request.Request(
        "https://demo.tradovateapi.com/v1/auth/accesstokenrequest",
        data=payload,
        headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read())
            if 'accessToken' in data:
                print(f"  AUTH SUCCESS! Token: {data['accessToken'][:10]}...")
            elif 'p-ticket' in data:
                print(f"  Got p-ticket (CAPTCHA={data.get('p-captcha', False)})")
            else:
                print(f"  Response: {json.dumps(data)[:200]}")
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:300]
        print(f"  HTTP {e.code}: {body}")
    except Exception as e:
        print(f"  Error: {e}")
else:
    print(f"  Missing creds: user={'set' if user else 'MISSING'}, pass={'set' if passwd else 'MISSING'}")
PYEOF

echo ""
echo "=== Done ==="
