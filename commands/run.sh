#!/bin/bash
# Trigger: v66
cd /root/MT5-PropFirm-Bot
date -u
echo "---ENV-TOKEN-CHECK---"
TOKEN=$(grep TRADOVATE_ACCESS_TOKEN .env 2>/dev/null | cut -d= -f2)
echo "Token length: ${#TOKEN}"
python3 -c "
import base64,json,time
t='$TOKEN'
if t and '.' in t:
 p=t.split('.')[1]+'=='
 d=json.loads(base64.urlsafe_b64decode(p))
 r=d.get('exp',0)-time.time()
 print(f'Remaining: {r:.0f}s ({r/3600:.1f}h)')
 print('VALID' if r>0 else 'EXPIRED')
else:
 print('No JWT')
" 2>&1
echo "---GIT-VERSION---"
git log --oneline -1
echo "---SERVICE---"
systemctl is-active futures-bot
echo "---JOURNAL---"
journalctl -u futures-bot --no-pager -n 20 --since "5 min ago" 2>/dev/null
echo "---BOT-LOG---"
tail -15 logs/bot.log 2>/dev/null
echo "---DONE---"
