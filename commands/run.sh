#!/bin/bash
# Trigger: diag-slim-v1
cd /root/MT5-PropFirm-Bot
echo "=== DIAGNOSTIC $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="
echo ""
echo "1.SERVICE: $(systemctl is-active futures-bot)"
echo "2.PID: $(systemctl show futures-bot -p MainPID --value)"
echo "3.UPTIME: $(systemctl show futures-bot -p ActiveEnterTimestamp --value)"
echo ""
echo "4.TOKEN:"
python3 -c "
import json,time,base64
d=json.load(open('configs/.tradovate_token.json'))
t=d['access_token'];p=t.split('.')[1];p+='='*(4-len(p)%4)
exp=json.loads(base64.urlsafe_b64decode(p)).get('exp',0)
print(f'  JWT expires in: {(exp-time.time())/3600:.1f}h')
print(f'  Saved at: {d.get(\"saved_at\",\"?\")}')" 2>&1
echo ""
echo "5.API:"
python3 -c "
import json,urllib.request
t=json.load(open('configs/.tradovate_token.json'))['access_token']
h={'Authorization':f'Bearer {t}','Content-Type':'application/json'}
r=urllib.request.urlopen(urllib.request.Request('https://demo.tradovateapi.com/v1/account/list',headers=h),timeout=5)
a=json.loads(r.read())
print(f'  Accounts: {len(a)}')
for x in a: print(f'  {x.get(\"name\")} id={x.get(\"id\")} active={x.get(\"active\")}')
r2=urllib.request.urlopen(urllib.request.Request('https://demo.tradovateapi.com/v1/cashBalance/getCashBalanceSnapshot?accountId=45373493',headers=h),timeout=5)
b=json.loads(r2.read())
print(f'  Balance: \${b.get(\"totalCashValue\",b.get(\"cashBalance\",\"?\"))}')
r3=urllib.request.urlopen(urllib.request.Request('https://demo.tradovateapi.com/v1/position/list',headers=h),timeout=5)
pos=[p for p in json.loads(r3.read()) if p.get('netPos',0)!=0]
print(f'  Open positions: {len(pos)}')
" 2>&1
echo ""
echo "6.TELEGRAM:"
python3 -c "
import json,urllib.request
env={}
for l in open('.env'):
 l=l.strip()
 if '=' in l and not l.startswith('#'): k,v=l.split('=',1);env[k]=v
t=env.get('TELEGRAM_TOKEN','')
r=urllib.request.urlopen(f'https://api.telegram.org/bot{t}/getMe',timeout=5)
d=json.loads(r.read())
print(f'  Bot: @{d[\"result\"][\"username\"]} OK')
" 2>&1
echo ""
echo "7.CONFIG:"
python3 -c "
import json
c=json.load(open('configs/bot_config.json'))
print(f'  Symbols: {c[\"symbols\"]}')
print(f'  Live: {c.get(\"live\",False)}')
g=c.get('guardian',{})
print(f'  MaxDD:\${g.get(\"max_drawdown\")} Target:\${g.get(\"profit_target\")} DayLoss:\${g.get(\"max_daily_loss\")} DayProfit:\${g.get(\"max_daily_profit\")}')
" 2>&1
echo ""
echo "8.NETWORK:"
curl -s -o /dev/null -w "  Tradovate: %{http_code} %{time_total}s\n" https://demo.tradovateapi.com/v1 --max-time 3
curl -s -o /dev/null -w "  Telegram:  %{http_code} %{time_total}s\n" https://api.telegram.org --max-time 3
echo ""
echo "9.LOGS (last 15):"
journalctl -u futures-bot --no-pager -n 15 --since "5 min ago" 2>/dev/null | grep -v "^--"
echo ""
echo "10.ERRORS:"
journalctl -u futures-bot --no-pager -n 50 | grep -i "error\|fail\|exception" | tail -5
echo ""
echo "=== DONE ==="
