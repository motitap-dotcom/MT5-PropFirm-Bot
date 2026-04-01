#!/bin/bash
# Trigger: v109 - Status check (don't restart!)
cd /root/MT5-PropFirm-Bot
echo "=== STATUS v109 ==="
date -u
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "=== Token file ==="
cat configs/.tradovate_token.json 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    t=d.get('access_token','')
    print(f'Token: {t[:30]}...' if len(t)>30 else f'Token: {t}')
    print(f'Expiry: {d.get(\"expiry\",\"?\")}')
    print(f'Saved: {d.get(\"saved_at\",\"?\")}')
except: print('Cannot parse token file')
" 2>/dev/null || echo "No token file"
echo ""
echo "=== Bot Log (last 30) ==="
tail -30 logs/bot.log 2>/dev/null || echo "No log"
echo ""
echo "=== Journal (last 10) ==="
journalctl -u futures-bot --no-pager -n 10 2>&1
echo "=== END ==="
