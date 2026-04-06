#!/bin/bash
# Trigger: v109 - Status check (no restart)
cd /root/MT5-PropFirm-Bot
echo "=== Status v109 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value 2>/dev/null)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value 2>/dev/null)"
echo ""
echo "=== Token ==="
python3 -c "
import json
from datetime import datetime, timezone
try:
    with open('configs/.tradovate_token.json') as f:
        t = json.load(f)
    exp = t.get('expirationTime','')
    print(f'Account: {t.get(\"accountSpec\",\"?\")}')
    print(f'Expires: {exp}')
    e = datetime.fromisoformat(exp.replace('Z','+00:00'))
    remaining = (e - datetime.now(timezone.utc)).total_seconds() / 60
    print(f'Remaining: {remaining:.0f} min')
except Exception as ex:
    print(f'Error: {ex}')
" 2>&1
echo ""
echo "=== Last 20 bot.log ==="
tail -20 logs/bot.log 2>/dev/null || echo "No bot.log"
