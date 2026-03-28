#!/bin/bash
# Trigger: auth-deep-debug-v2
echo "=== DEEP AUTH DIAGNOSTIC ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

cd /root/MT5-PropFirm-Bot
source .env 2>/dev/null

python3 << 'PYEOF'
import os, json, urllib.request, urllib.error, base64, time

user = os.environ.get('TRADOVATE_USER', '')
passwd = os.environ.get('TRADOVATE_PASS', '')
token = os.environ.get('TRADOVATE_ACCESS_TOKEN', '')

print(f"Username: {user}")
print(f"Password length: {len(passwd)}")
print(f"Token length: {len(token)}")
print()

# Decode JWT to check expiry
if token:
    try:
        payload_b64 = token.split('.')[1]
        # Add padding
        payload_b64 += '=' * (4 - len(payload_b64) % 4)
        payload = json.loads(base64.urlsafe_b64decode(payload_b64))
        exp = payload.get('exp', 0)
        now = time.time()
        print(f"=== JWT TOKEN ANALYSIS ===")
        print(f"Subject (user ID): {payload.get('sub')}")
        print(f"Email: {payload.get('email')}")
        print(f"Expiry: {exp} ({time.strftime('%Y-%m-%d %H:%M UTC', time.gmtime(exp))})")
        print(f"Now:    {int(now)} ({time.strftime('%Y-%m-%d %H:%M UTC', time.gmtime(now))})")
        print(f"Status: {'EXPIRED' if now > exp else 'VALID'} (expired {(now-exp)/3600:.1f}h ago)" if now > exp else f"Valid for {(exp-now)/3600:.1f}h")
        email = payload.get('email', '')
    except Exception as e:
        print(f"JWT decode error: {e}")
        email = ''
else:
    email = ''
print()

def try_auth(label, name, password, org=""):
    print(f"=== AUTH TEST: {label} ===")
    payload = json.dumps({
        'name': name,
        'password': password,
        'appId': 'tradovate_trader(web)',
        'appVersion': '3.260220.0',
        'deviceId': 'diag-test-002',
        'cid': 8,
        'sec': '',
        'organization': org,
    }).encode()
    req = urllib.request.Request(
        'https://demo.tradovateapi.com/v1/auth/accesstokenrequest',
        data=payload,
        headers={'Content-Type': 'application/json'}
    )
    try:
        resp = urllib.request.urlopen(req, timeout=15)
        data = json.loads(resp.read())
        if 'accessToken' in data:
            print(f"SUCCESS! Got token (len={len(data['accessToken'])})")
            print(f"Expiry: {data.get('expirationTime', 'unknown')}")
            # Save the token!
            save_token(data)
            return True
        elif 'p-ticket' in data:
            print(f"CAPTCHA/WAIT required:")
            print(f"  p-captcha: {data.get('p-captcha', False)}")
            print(f"  p-time: {data.get('p-time', 0)}")
            # If no captcha, wait and retry
            if not data.get('p-captcha', False):
                p_time = data.get('p-time', 15)
                print(f"  Waiting {p_time}s and retrying...")
                import time
                time.sleep(p_time)
                payload2 = json.loads(payload)
                payload2['p-ticket'] = data['p-ticket']
                req2 = urllib.request.Request(
                    'https://demo.tradovateapi.com/v1/auth/accesstokenrequest',
                    data=json.dumps(payload2).encode(),
                    headers={'Content-Type': 'application/json'}
                )
                try:
                    resp2 = urllib.request.urlopen(req2, timeout=15)
                    data2 = json.loads(resp2.read())
                    if 'accessToken' in data2:
                        print(f"  SUCCESS after wait! Token len={len(data2['accessToken'])}")
                        save_token(data2)
                        return True
                    else:
                        print(f"  Still failed: {data2.get('errorText', str(data2))}")
                except urllib.error.HTTPError as e2:
                    print(f"  Retry HTTP error: {e2.code} {e2.read().decode()[:200]}")
            return False
        else:
            print(f"FAILED: {data.get('errorText', json.dumps(data)[:200])}")
            return False
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"HTTP {e.code}: {body[:300]}")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False

def save_token(data):
    """Save successful token everywhere"""
    token = data['accessToken']
    md_token = data.get('mdAccessToken', token)
    expiry_str = data.get('expirationTime', '')

    # Parse expiry
    try:
        from datetime import datetime
        dt = datetime.fromisoformat(expiry_str.replace('Z', '+00:00'))
        expiry = dt.timestamp()
    except:
        expiry = time.time() + 86400

    # Save to token file
    token_data = {
        'access_token': token,
        'md_access_token': md_token,
        'expiry': expiry,
        'saved_at': time.strftime('%Y-%m-%dT%H:%M:%S+00:00', time.gmtime()),
    }
    os.makedirs('configs', exist_ok=True)
    with open('configs/.tradovate_token.json', 'w') as f:
        json.dump(token_data, f)
    print("  Saved to configs/.tradovate_token.json")

    # Update .env
    if os.path.exists('.env'):
        lines = open('.env').read().splitlines()
        new_lines = []
        updated = False
        for line in lines:
            if line.startswith('TRADOVATE_ACCESS_TOKEN='):
                new_lines.append(f'TRADOVATE_ACCESS_TOKEN={token}')
                updated = True
            else:
                new_lines.append(line)
        if not updated:
            new_lines.append(f'TRADOVATE_ACCESS_TOKEN={token}')
        open('.env', 'w').write('\n'.join(new_lines) + '\n')
        print("  Updated .env")

    # Update systemd drop-in
    try:
        dropin = '/etc/systemd/system/futures-bot.service.d/env.conf'
        if os.path.exists(dropin):
            lines = open(dropin).read().splitlines()
            new_lines = []
            for line in lines:
                if 'TRADOVATE_ACCESS_TOKEN=' in line:
                    new_lines.append(f'Environment="TRADOVATE_ACCESS_TOKEN={token}"')
                else:
                    new_lines.append(line)
            open(dropin, 'w').write('\n'.join(new_lines) + '\n')
            os.system('systemctl daemon-reload')
            print("  Updated systemd drop-in")
    except Exception as e:
        print(f"  Could not update systemd: {e}")

# Test 1: Token renewal
print("=== TOKEN RENEWAL TEST ===")
if token:
    req = urllib.request.Request(
        'https://demo.tradovateapi.com/v1/auth/renewaccesstoken',
        data=b'',
        headers={
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        },
        method='POST'
    )
    try:
        resp = urllib.request.urlopen(req, timeout=10)
        data = json.loads(resp.read())
        if 'accessToken' in data:
            print(f"RENEWAL SUCCESS! New token len={len(data['accessToken'])}")
            save_token(data)
        else:
            print(f"Renewal response: {json.dumps(data)[:200]}")
    except urllib.error.HTTPError as e:
        print(f"Renewal failed HTTP {e.code}: {e.read().decode()[:200]}")
    except Exception as e:
        print(f"Renewal error: {e}")
else:
    print("No token to renew")
print()

# Test 2: Username auth
success = try_auth("Username + Password", user, passwd)
print()

# Test 3: Email auth (if we got email from JWT)
if not success and email:
    print()
    success = try_auth("Email + Password", email, passwd)
    print()

# Test 4: Try with organization variations for TradeDay
if not success:
    for org in ["TradeDay", "tradeday", "TRADEDAY"]:
        print()
        success = try_auth(f"Username + Password + org={org}", user, passwd, org)
        if success:
            break
    print()

# Final: restart bot if we got a token
if success:
    print()
    print("=== RESTARTING BOT WITH FRESH TOKEN ===")
    os.system('systemctl daemon-reload')
    os.system('systemctl restart futures-bot')
    import time
    time.sleep(5)
    os.system('systemctl is-active futures-bot')
    os.system('journalctl -u futures-bot --no-pager -n 25 --since "30 sec ago"')
else:
    print()
    print("ALL AUTH ATTEMPTS FAILED")
    print("Possible causes:")
    print("  1. Password was changed on Tradovate")
    print("  2. Account locked due to too many failed attempts")
    print("  3. Need to solve CAPTCHA from this IP first")
    print("  4. TradeDay account expired or deactivated")
PYEOF

echo ""
echo "=== DIAGNOSTIC COMPLETE ==="
