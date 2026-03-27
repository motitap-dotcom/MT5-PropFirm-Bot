#!/bin/bash
# Trigger: v37 - fix token + restart bot
echo "=== Fix Token & Restart Bot ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"

cd /root/MT5-PropFirm-Bot

# STEP 1: Pull latest code
echo ""
echo "--- Pulling latest code ---"
git fetch origin
git reset --hard origin/claude/build-cfd-trading-bot-fl0ld 2>/dev/null || git reset --hard origin/main
echo "Code updated"

# STEP 2: Remove old token so bot re-authenticates
echo ""
echo "--- Clearing old token ---"
rm -f configs/.tradovate_token.json
echo "Old token file removed"

# STEP 3: Update .env with fresh credentials from workflow env vars
echo ""
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
            print(f".env updated with token ({len(token)} chars)")
        else:
            print(".env updated WITHOUT token (will use user/pass auth)")
        f.write(f'TELEGRAM_TOKEN={tg_token}\n')
        f.write(f'TELEGRAM_CHAT_ID={tg_chat}\n')
    print(f"Credentials: user={user[:3]}***, pass={'set' if passwd else 'MISSING'}")
else:
    print("WARNING: No env vars from workflow! .env not updated")
    if os.path.exists('.env'):
        with open('.env') as f:
            lines = [l.strip() for l in f if '=' in l and not l.startswith('#')]
        print(f"Existing .env has {len(lines)} vars")
PYEOF

# STEP 4: Set up systemd env override
echo ""
echo "--- Configuring systemd ---"
python3 -c "
import os
if os.path.exists('.env'):
    with open('.env') as f:
        content = f.read()
    os.makedirs('/etc/systemd/system/futures-bot.service.d', exist_ok=True)
    with open('/etc/systemd/system/futures-bot.service.d/env.conf', 'w') as f:
        f.write('[Service]\n')
        for line in content.strip().split('\n'):
            if '=' in line and not line.startswith('#'):
                f.write(f'Environment=\"{line.strip()}\"\n')
    print('Systemd env override written')
else:
    print('No .env file!')
"

# STEP 5: Restart bot
echo ""
echo "--- Restarting bot ---"
systemctl daemon-reload
systemctl stop futures-bot 2>/dev/null
sleep 3
systemctl start futures-bot
sleep 8

# STEP 6: Check results
echo ""
echo "--- Service Status ---"
systemctl is-active futures-bot

echo ""
echo "--- Logs (last 30 lines) ---"
tail -30 logs/bot.log 2>/dev/null || journalctl -u futures-bot --no-pager -n 30

echo ""
echo "--- Bot Process ---"
ps aux | grep -E '[p]ython.*bot' || echo "No bot process found"

echo ""
echo "=== Done ==="
