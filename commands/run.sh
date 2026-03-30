#!/bin/bash
# Trigger: v60 - Check token + try restart
cd /root/MT5-PropFirm-Bot
date -u

echo "---TOKEN-IN-ENV---"
# Show first 20 and last 10 chars of token
TOKEN=$(grep TRADOVATE_ACCESS_TOKEN .env | cut -d= -f2)
echo "Length: ${#TOKEN}"
echo "Start: ${TOKEN:0:20}..."
echo "End: ...${TOKEN: -10}"

echo "---TOKEN-EXPIRY-CHECK---"
# Decode JWT and check exp
python3 -c "
import base64, json, time
token = '''$TOKEN'''
if token:
    parts = token.split('.')
    if len(parts) >= 2:
        payload = parts[1] + '=='
        data = json.loads(base64.urlsafe_b64decode(payload))
        exp = data.get('exp', 0)
        now = time.time()
        remaining = exp - now
        print(f'Token exp: {exp}')
        print(f'Now: {now:.0f}')
        print(f'Remaining: {remaining:.0f}s ({remaining/3600:.1f}h)')
        if remaining > 0:
            print('TOKEN IS VALID')
        else:
            print('TOKEN IS EXPIRED')
else:
    print('No token found')
" 2>&1

echo "---STOP-BOT---"
systemctl stop futures-bot 2>/dev/null
sleep 2

echo "---QUICK-AUTH-TEST---"
timeout 30 python3 -c "
import sys, os, asyncio
sys.path.insert(0, '.')
os.environ.setdefault('TRADOVATE_ACCESS_TOKEN', '$TOKEN')
from futures_bot.core.tradovate_client import TradovateClient
async def test():
    c = TradovateClient(
        username=os.environ.get('TRADOVATE_USER',''),
        password=os.environ.get('TRADOVATE_PASS',''),
    )
    try:
        await c.connect()
        print(f'AUTH OK! account={c.account_id}')
        c._save_token()
        print('Token saved')
        await c.disconnect()
    except Exception as e:
        print(f'AUTH FAIL: {e}')
        if c.session: await c.session.close()
asyncio.run(test())
" 2>&1

echo "---START-BOT---"
systemctl start futures-bot
sleep 5

echo "---STATUS---"
systemctl is-active futures-bot
journalctl -u futures-bot --no-pager -n 15 --since "10 sec ago"
echo "---DONE---"
