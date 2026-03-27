#!/bin/bash
# Trigger: v48 - deploy chart fix + restart
echo "=== Deploy & Restart ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot
git fetch origin claude/build-cfd-trading-bot-fl0ld
git reset --hard origin/claude/build-cfd-trading-bot-fl0ld
mkdir -p status logs
# Env
python3 -c "
import os
t=os.environ.get('TRADOVATE_ACCESS_TOKEN','').strip()
u=os.environ.get('TRADOVATE_USER','').strip()
p=os.environ.get('TRADOVATE_PASS','').strip()
tt=os.environ.get('TELEGRAM_TOKEN','').strip()
tc=os.environ.get('TELEGRAM_CHAT_ID','').strip()
if u:
    with open('.env','w') as f:
        f.write(f'TRADOVATE_USER={u}\nTRADOVATE_PASS={p}\n')
        if t: f.write(f'TRADOVATE_ACCESS_TOKEN={t}\n')
        f.write(f'TELEGRAM_TOKEN={tt}\nTELEGRAM_CHAT_ID={tc}\n')
    print(f'Token: {len(t)} chars')
if os.path.exists('configs/.tradovate_token.json'): os.remove('configs/.tradovate_token.json')
"
# Systemd
python3 -c "
import os
with open('.env') as f: c=f.read()
os.makedirs('/etc/systemd/system/futures-bot.service.d',exist_ok=True)
with open('/etc/systemd/system/futures-bot.service.d/env.conf','w') as f:
    f.write('[Service]\n')
    for l in c.strip().split('\n'):
        if '=' in l and not l.startswith('#'): f.write(f'Environment=\"{l.strip()}\"\n')
"
systemctl daemon-reload
systemctl stop futures-bot 2>/dev/null
sleep 2
systemctl start futures-bot
sleep 12
echo "--- Service ---"
systemctl is-active futures-bot
echo "--- Last 25 log ---"
tail -25 logs/bot.log
echo "=== Done ==="
