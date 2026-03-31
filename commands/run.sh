#!/bin/bash
# Trigger: v93 - Read previous output + quick password debug
cd /root/MT5-PropFirm-Bot

echo "=== QUICK DEBUG ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

# Check if previous run left output
if [ -f "/tmp/auth_test_output.txt" ]; then
    echo "=== Previous test output ==="
    cat /tmp/auth_test_output.txt
    echo ""
fi

# Password debug
echo "=== Password Check ==="
echo "TRADOVATE_USER from env: '${TRADOVATE_USER}'"
echo "TRADOVATE_PASS from env length: ${#TRADOVATE_PASS}"

# Check .env file content
echo ""
echo "=== .env file (masked) ==="
while IFS= read -r line; do
    key=$(echo "$line" | cut -d= -f1)
    val=$(echo "$line" | cut -d= -f2-)
    echo "  $key = [${#val} chars] first='${val:0:1}' last='${val: -1}'"
done < .env

echo ""

# Quick API test (no browser, just API)
PY="python3"
[ -d "venv" ] && PY="venv/bin/python3"

$PY -c "
import os, requests, uuid
u = os.environ.get('TRADOVATE_USER','')
p = os.environ.get('TRADOVATE_PASS','')
print(f'Testing with user={u}, pass_len={len(p)}, pass_repr={repr(p)}')
payload = {'name': u, 'password': p, 'appId': 'tradovate_trader(web)',
           'appVersion': '3.260220.0', 'deviceId': str(uuid.uuid4()),
           'cid': 8, 'sec': '', 'organization': ''}
try:
    r = requests.post('https://demo.tradovateapi.com/v1/auth/accesstokenrequest', json=payload, timeout=15)
    d = r.json()
    print(f'Response: {str(d)[:200]}')
except Exception as e:
    print(f'Error: {e}')
" 2>&1

echo ""
echo "=== END ==="
