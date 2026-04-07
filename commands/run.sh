#!/bin/bash
# Trigger: v119 - Status after FundedNext config
cd /root/MT5-PropFirm-Bot
echo "=== Status v119 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value 2>/dev/null)"
echo ""
echo "=== Token ==="
python3 -c "
import json
from datetime import datetime, timezone
try:
    with open('configs/.tradovate_token.json') as f:
        t = json.load(f)
    print(f'Account: {t.get(\"accountSpec\",\"?\")}')
    exp = t.get('expirationTime','')
    if exp:
        e = datetime.fromisoformat(exp.replace('Z','+00:00'))
        remaining = (e - datetime.now(timezone.utc)).total_seconds() / 60
        print(f'Remaining: {remaining:.0f} min')
except Exception as ex:
    print(f'Error: {ex}')
" 2>&1
echo ""
echo "=== Config org ==="
python3 -c "import json; c=json.load(open('configs/bot_config.json')); print(f'organization: \"{c.get(\"organization\",\"\")}\"')" 2>&1
echo ""
echo "=== Last 25 bot.log ==="
tail -25 logs/bot.log 2>/dev/null || echo "No bot.log"
