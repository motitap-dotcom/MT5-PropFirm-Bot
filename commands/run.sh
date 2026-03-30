#!/bin/bash
# Trigger: v58 - Fix service + check auth
cd /root/MT5-PropFirm-Bot

echo "=== TIMESTAMP ==="
date -u

echo ""
echo "=== SYSTEMD SERVICE FILE ==="
cat /etc/systemd/system/futures-bot.service

echo ""
echo "=== .ENV FILE (redacted) ==="
if [ -f .env ]; then
    # Show keys but redact values
    sed 's/=.*/=***REDACTED***/' .env
else
    echo ".env NOT FOUND"
fi

echo ""
echo "=== TEST IMPORT ==="
cd /root/MT5-PropFirm-Bot
python3 -c "
import sys
sys.path.insert(0, '.')
from futures_bot.core.tradovate_client import TradovateClient
print('Import OK')
print(f'Python: {sys.executable}')
print(f'Path: {sys.path[:3]}')
"

echo ""
echo "=== TEST AUTH (quick) ==="
cd /root/MT5-PropFirm-Bot
python3 -c "
import sys, os, asyncio, json
sys.path.insert(0, '.')
from futures_bot.core.tradovate_client import TradovateClient

async def test():
    client = TradovateClient(
        username=os.environ.get('TRADOVATE_USER', ''),
        password=os.environ.get('TRADOVATE_PASS', ''),
        live=False
    )
    try:
        await client.connect()
        print(f'SUCCESS! account_id={client.account_id}')
        print(f'Token expiry: {client.token_expiry}')
        # Save token for the service to use
        client._save_token()
        print('Token saved to file')
        # Also update .env
        env_path = '/root/MT5-PropFirm-Bot/.env'
        if os.path.exists(env_path):
            lines = open(env_path).read().splitlines()
            new_lines = []
            updated = False
            for line in lines:
                if line.startswith('TRADOVATE_ACCESS_TOKEN='):
                    new_lines.append(f'TRADOVATE_ACCESS_TOKEN={client.access_token}')
                    updated = True
                else:
                    new_lines.append(line)
            if not updated:
                new_lines.append(f'TRADOVATE_ACCESS_TOKEN={client.access_token}')
            open(env_path, 'w').write('\n'.join(new_lines) + '\n')
            print('Token written to .env')
        await client.disconnect()
    except Exception as e:
        print(f'FAILED: {e}')
        if client.session:
            await client.session.close()

asyncio.run(test())
" 2>&1

echo ""
echo "=== TOKEN FILE AFTER TEST ==="
cat configs/.tradovate_token.json 2>/dev/null || echo "No token file"
