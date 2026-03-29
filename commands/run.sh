#!/bin/bash
# Trigger: save-token-and-start-v1
echo "=== SAVING FRESH TOKEN AND STARTING BOT ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

cd /root/MT5-PropFirm-Bot

TOKEN="eyJraWQiOiIyOCIsImFsZyI6IkVkRFNBIn0.eyJzdWIiOiI3MTg1OTg3IiwiZXhwIjoxNzc0NzYzOTI0LCJqdGkiOiItNjQzMzM4MDM3OTgwNTc2MzQ5My0tNTc2MDk1NTU1NzA2OTQ0NDA1MSIsInBocyI6LTE0OTM4NzI5MDQsImVtYWlsIjoibW90aXRhcEBnbWFpbC5jb20ifQ.iEun7rwIXNNxvmnEXQ8H1NRHuFo8NN_83U8a7XvPb4cJsfmCmJi1Gwm1duMZG-bePlyIM0pUa7tShTP06Xx3Aw"

# 1. Verify token works
echo "=== VERIFYING TOKEN ==="
python3 << PYEOF
import urllib.request, urllib.error, json, time, base64

token = "${TOKEN}"

# Decode JWT expiry
payload_b64 = token.split('.')[1]
payload_b64 += '=' * (4 - len(payload_b64) % 4)
payload = json.loads(base64.urlsafe_b64decode(payload_b64))
exp = payload.get('exp', 0)
now = time.time()
print(f"Token expiry: {time.strftime('%Y-%m-%d %H:%M UTC', time.gmtime(exp))}")
print(f"Time remaining: {(exp-now)/3600:.1f} hours")

# Test token against API
req = urllib.request.Request(
    'https://demo.tradovateapi.com/v1/account/list',
    headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
)
try:
    resp = urllib.request.urlopen(req, timeout=10)
    data = json.loads(resp.read())
    print(f"TOKEN VALID! Found {len(data)} account(s)")
    for acc in data:
        print(f"  Account: {acc.get('name', 'unknown')} (ID: {acc.get('id', '?')})")
except urllib.error.HTTPError as e:
    print(f"Token test failed: HTTP {e.code} {e.read().decode()[:200]}")
except Exception as e:
    print(f"Token test error: {e}")
PYEOF
echo ""

# 2. Save to token file
echo "=== SAVING TOKEN FILE ==="
python3 << PYEOF
import json, time, base64

token = "${TOKEN}"

# Get real expiry from JWT
payload_b64 = token.split('.')[1]
payload_b64 += '=' * (4 - len(payload_b64) % 4)
payload = json.loads(base64.urlsafe_b64decode(payload_b64))
expiry = payload.get('exp', time.time() + 86400)

token_data = {
    "access_token": token,
    "md_access_token": token,
    "expiry": expiry,
    "saved_at": time.strftime("%Y-%m-%dT%H:%M:%S+00:00", time.gmtime()),
}
with open('configs/.tradovate_token.json', 'w') as f:
    json.dump(token_data, f, indent=2)
print("Saved to configs/.tradovate_token.json")
PYEOF
echo ""

# 3. Update .env
echo "=== UPDATING .ENV ==="
if [ -f .env ]; then
    if grep -q "TRADOVATE_ACCESS_TOKEN=" .env; then
        sed -i "s|TRADOVATE_ACCESS_TOKEN=.*|TRADOVATE_ACCESS_TOKEN=${TOKEN}|" .env
        echo "Updated existing TRADOVATE_ACCESS_TOKEN in .env"
    else
        echo "TRADOVATE_ACCESS_TOKEN=${TOKEN}" >> .env
        echo "Added TRADOVATE_ACCESS_TOKEN to .env"
    fi
else
    echo "ERROR: .env not found!"
fi
echo ""

# 4. Update systemd drop-in with PROPERLY QUOTED values
echo "=== FIXING SYSTEMD DROP-IN ==="
source .env
cat > /etc/systemd/system/futures-bot.service.d/env.conf << DROPEOF
[Service]
Environment="TRADOVATE_USER=${TRADOVATE_USER}"
Environment="TRADOVATE_PASS=${TRADOVATE_PASS}"
Environment="TRADOVATE_ACCESS_TOKEN=${TOKEN}"
Environment="TELEGRAM_TOKEN=${TELEGRAM_TOKEN}"
Environment="TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}"
DROPEOF
echo "Fixed systemd drop-in (proper quoting)"
systemctl daemon-reload
echo ""

# 5. Pull latest code
echo "=== PULLING LATEST CODE ==="
git fetch origin claude/fix-bot-functionality-h1Sb3
git reset --hard origin/claude/fix-bot-functionality-h1Sb3
echo ""

# 6. Create logs and status directories
mkdir -p logs status

# 7. Restart bot
echo "=== RESTARTING BOT ==="
systemctl stop futures-bot 2>/dev/null
sleep 2
systemctl start futures-bot
sleep 5

echo "=== BOT STATUS ==="
systemctl is-active futures-bot
echo ""

echo "=== RECENT LOGS ==="
journalctl -u futures-bot --no-pager -n 30 --since "30 sec ago"
echo ""

echo "=== DONE ==="
