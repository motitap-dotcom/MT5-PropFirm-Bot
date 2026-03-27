#!/bin/bash
# Trigger: v45 - deploy MD URL fix + restart
echo "=== Deploy & Restart ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot

# Update code
git fetch origin claude/build-cfd-trading-bot-fl0ld
git reset --hard origin/claude/build-cfd-trading-bot-fl0ld

# Create status dir
mkdir -p status logs

# Update .env
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
        if token: f.write(f'TRADOVATE_ACCESS_TOKEN={token}\n')
        f.write(f'TELEGRAM_TOKEN={tg_token}\n')
        f.write(f'TELEGRAM_CHAT_ID={tg_chat}\n')
    print(f"Token: {len(token)} chars")
os.remove('configs/.tradovate_token.json') if os.path.exists('configs/.tradovate_token.json') else None
PYEOF

# Systemd env
python3 -c "
import os
with open('.env') as f: content = f.read()
os.makedirs('/etc/systemd/system/futures-bot.service.d', exist_ok=True)
with open('/etc/systemd/system/futures-bot.service.d/env.conf', 'w') as f:
    f.write('[Service]\n')
    for line in content.strip().split('\n'):
        if '=' in line and not line.startswith('#'):
            f.write(f'Environment=\"{line.strip()}\"\n')
"

# Restart
systemctl daemon-reload
systemctl stop futures-bot 2>/dev/null
sleep 2
systemctl start futures-bot
sleep 10

echo "--- Service ---"
systemctl is-active futures-bot
echo "--- Verify MD fix ---"
grep -c "md_base_url" futures_bot/core/tradovate_client.py && echo "MD URL FIX DEPLOYED" || echo "NOT DEPLOYED"
echo "--- Last 20 log lines ---"
tail -20 logs/bot.log
echo "=== Done ==="
