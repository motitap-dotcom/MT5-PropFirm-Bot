#!/bin/bash
# Trigger: auth-debug-v1
echo "=== AUTH DIAGNOSTIC ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

cd /root/MT5-PropFirm-Bot

# 1. Check .env format (redacted values)
echo "=== .ENV FORMAT CHECK ==="
if [ -f .env ]; then
    echo "Lines in .env:"
    wc -l .env
    echo ""
    echo "Variable names and value lengths (redacted):"
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        key=$(echo "$line" | cut -d= -f1)
        val=$(echo "$line" | cut -d= -f2-)
        echo "  $key = [${#val} chars]"
        # Check for quoting issues
        if [[ "$val" == \"*\" ]] || [[ "$val" == \'*\' ]]; then
            echo "    WARNING: Value is quoted - systemd EnvironmentFile includes quotes as part of the value!"
        fi
        # Check for spaces
        if [[ "$val" == *" "* ]]; then
            echo "    WARNING: Value contains spaces"
        fi
    done < .env
else
    echo ".env MISSING!"
fi
echo ""

# 2. Check what systemd actually sees
echo "=== SYSTEMD ENV CHECK ==="
systemctl show futures-bot --property=Environment 2>/dev/null || echo "Could not read service env"
echo ""
# Check the drop-in
echo "=== SYSTEMD DROP-IN ==="
if [ -d /etc/systemd/system/futures-bot.service.d/ ]; then
    echo "Drop-in files:"
    ls -la /etc/systemd/system/futures-bot.service.d/
    echo ""
    for f in /etc/systemd/system/futures-bot.service.d/*.conf; do
        echo "--- $f ---"
        cat "$f" | sed 's/PASS=.*/PASS=[REDACTED]/' | sed 's/TOKEN=.*/TOKEN=[REDACTED]/' | sed 's/ACCESS_TOKEN=.*/ACCESS_TOKEN=[REDACTED]/'
    done
else
    echo "No drop-in directory"
fi
echo ""

# 3. Check token file content
echo "=== TOKEN FILE CONTENT ==="
if [ -f configs/.tradovate_token.json ]; then
    python3 -c "
import json
with open('configs/.tradovate_token.json') as f:
    d = json.load(f)
print(f'Keys: {list(d.keys())}')
print(f'Has access_token: {bool(d.get(\"access_token\"))}')
print(f'Token length: {len(d.get(\"access_token\", \"\"))}')
print(f'Expiry timestamp: {d.get(\"expiry\", \"missing\")}')
print(f'Saved at: {d.get(\"saved_at\", \"missing\")}')
import time
exp = d.get('expiry', 0)
if exp:
    remaining = exp - time.time()
    print(f'Time remaining: {remaining/3600:.1f} hours ({\"VALID\" if remaining > 0 else \"EXPIRED\"})')
" 2>&1
else
    echo "No token file"
fi
echo ""

# 4. Try actual auth request (just check response, don't log password)
echo "=== AUTH TEST ==="
source .env 2>/dev/null
python3 -c "
import os, json
try:
    import requests
except ImportError:
    print('requests not installed, using urllib')
    import urllib.request, urllib.error

user = os.environ.get('TRADOVATE_USER', '')
passwd = os.environ.get('TRADOVATE_PASS', '')
print(f'Username length: {len(user)}')
print(f'Password length: {len(passwd)}')
print(f'Username first 3 chars: {user[:3]}...')

if not user or not passwd:
    print('ERROR: Missing credentials!')
else:
    import urllib.request, urllib.error
    payload = json.dumps({
        'name': user,
        'password': passwd,
        'appId': 'tradovate_trader(web)',
        'appVersion': '3.260220.0',
        'deviceId': 'diag-test-001',
        'cid': 8,
        'sec': '',
    }).encode()
    req = urllib.request.Request(
        'https://demo.tradovateapi.com/v1/auth/accesstokenrequest',
        data=payload,
        headers={'Content-Type': 'application/json'}
    )
    try:
        resp = urllib.request.urlopen(req, timeout=10)
        data = json.loads(resp.read())
        if 'accessToken' in data:
            print('AUTH SUCCESS! Got access token')
            print(f'Token length: {len(data[\"accessToken\"])}')
            print(f'Expiry: {data.get(\"expirationTime\", \"unknown\")}')
            # Save fresh token
            token_data = {
                'access_token': data['accessToken'],
                'md_access_token': data.get('mdAccessToken', data['accessToken']),
                'expiry': 0,  # Will be set properly by bot
                'saved_at': ''
            }
            with open('configs/.tradovate_token.json', 'w') as f:
                json.dump(token_data, f)
            print('Saved fresh token to configs/.tradovate_token.json')
            # Update .env
            if os.path.exists('.env'):
                lines = open('.env').read().splitlines()
                new_lines = []
                updated = False
                for line in lines:
                    if line.startswith('TRADOVATE_ACCESS_TOKEN='):
                        new_lines.append(f'TRADOVATE_ACCESS_TOKEN={data[\"accessToken\"]}')
                        updated = True
                    else:
                        new_lines.append(line)
                if not updated:
                    new_lines.append(f'TRADOVATE_ACCESS_TOKEN={data[\"accessToken\"]}')
                open('.env', 'w').write(chr(10).join(new_lines) + chr(10))
                print('Updated .env with fresh token')
        elif 'p-ticket' in data:
            print(f'Got p-ticket (CAPTCHA/wait required)')
            print(f'p-captcha: {data.get(\"p-captcha\", False)}')
            print(f'p-time: {data.get(\"p-time\", 0)}')
        else:
            print(f'Auth response keys: {list(data.keys())}')
            print(f'Error: {data.get(\"errorText\", \"unknown\")}')
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f'HTTP Error {e.code}: {body[:500]}')
    except Exception as e:
        print(f'Request failed: {e}')
" 2>&1
echo ""

# 5. Service restart test
echo "=== RESTART BOT ==="
systemctl daemon-reload
systemctl restart futures-bot
sleep 3
systemctl is-active futures-bot
journalctl -u futures-bot --no-pager -n 20 --since "30 sec ago"
echo ""
echo "=== DIAGNOSTIC COMPLETE ==="
