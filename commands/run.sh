#!/bin/bash
# Trigger: v61 - Update .env with fresh token from GitHub Secrets + restart
cd /root/MT5-PropFirm-Bot
date -u

echo "---UPDATING-ENV-FILE---"
# The GitHub Actions workflow passes secrets as env vars to this SSH session
# We need to write them to .env so the systemd service can use them

# Build fresh .env from GitHub Secrets (available as env vars)
cat > .env << ENVEOF
TRADOVATE_USER=${TRADOVATE_USER}
TRADOVATE_PASS=${TRADOVATE_PASS}
TRADOVATE_ACCESS_TOKEN=${TRADOVATE_ACCESS_TOKEN}
TELEGRAM_TOKEN=${TELEGRAM_TOKEN}
TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
ENVEOF

echo ".env updated with fresh secrets"

echo "---TOKEN-CHECK---"
TOKEN="${TRADOVATE_ACCESS_TOKEN}"
echo "Token length: ${#TOKEN}"
python3 -c "
import base64, json, time
token = '${TRADOVATE_ACCESS_TOKEN}'
if token and '.' in token:
    parts = token.split('.')
    payload = parts[1] + '=='
    data = json.loads(base64.urlsafe_b64decode(payload))
    exp = data.get('exp', 0)
    remaining = exp - time.time()
    print(f'Expires in: {remaining:.0f}s ({remaining/3600:.1f}h)')
    print('VALID' if remaining > 0 else 'EXPIRED')
else:
    print('No valid JWT token')
" 2>&1

echo "---CLEAR-OLD-TOKEN-FILE---"
rm -f configs/.tradovate_token.json

echo "---RESTART-BOT---"
systemctl stop futures-bot 2>/dev/null
sleep 2
systemctl daemon-reload
systemctl start futures-bot
sleep 8

echo "---STATUS---"
systemctl is-active futures-bot
journalctl -u futures-bot --no-pager -n 20 --since "15 sec ago"

echo "---BOT-LOG---"
tail -15 logs/bot.log 2>/dev/null || echo "No log"
echo "---DONE---"
