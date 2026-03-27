#!/bin/bash
# Trigger: v42 - deploy token fix + restart with new token
echo "=== Deploy & Restart ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot

# Update code
echo "--- Updating code ---"
git fetch origin claude/build-cfd-trading-bot-fl0ld
git reset --hard origin/claude/build-cfd-trading-bot-fl0ld
echo "Done"

# Update .env with fresh token from GitHub Secrets
echo "--- Updating .env ---"
python3 << 'PYEOF'
import os
token = os.environ.get('TRADOVATE_ACCESS_TOKEN', '').strip()
user = os.environ.get('TRADOVATE_USER', '').strip()
passwd = os.environ.get('TRADOVATE_PASS', '').strip()
tg_token = os.environ.get('TELEGRAM_TOKEN', '').strip()
tg_chat = os.environ.get('TELEGRAM_CHAT_ID', '').strip()
if user:
    with open('.env', 'w') as f:
        f.write(f'TRADOVATE_USER={user}\n')
        f.write(f'TRADOVATE_PASS={passwd}\n')
        if token:
            f.write(f'TRADOVATE_ACCESS_TOKEN={token}\n')
        f.write(f'TELEGRAM_TOKEN={tg_token}\n')
        f.write(f'TELEGRAM_CHAT_ID={tg_chat}\n')
    print(f"Token: {'yes (' + str(len(token)) + ' chars)' if token else 'NO'}")
# Clear old saved token so bot uses fresh env token
os.remove('configs/.tradovate_token.json') if os.path.exists('configs/.tradovate_token.json') else None
print("Old token file cleared")
PYEOF

# Systemd env override
python3 -c "
import os
with open('.env') as f: content = f.read()
os.makedirs('/etc/systemd/system/futures-bot.service.d', exist_ok=True)
with open('/etc/systemd/system/futures-bot.service.d/env.conf', 'w') as f:
    f.write('[Service]\n')
    for line in content.strip().split('\n'):
        if '=' in line and not line.startswith('#'):
            f.write(f'Environment=\"{line.strip()}\"\n')
print('Systemd override updated')
"

# Restart
echo "--- Restarting ---"
systemctl daemon-reload
systemctl stop futures-bot 2>/dev/null
sleep 2
systemctl start futures-bot
sleep 10

echo "--- Service ---"
systemctl is-active futures-bot
echo "--- Last 20 log lines ---"
tail -20 logs/bot.log 2>/dev/null
echo "=== Done ==="
