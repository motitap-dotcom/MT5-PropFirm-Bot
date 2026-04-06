#!/bin/bash
# Trigger: v106 - Final status check
cd /root/MT5-PropFirm-Bot
echo "=== Status v106 ==="
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
    print(f'Expires: {exp}')
    e = datetime.fromisoformat(exp.replace('Z','+00:00'))
    remaining = (e - datetime.now(timezone.utc)).total_seconds() / 60
    print(f'Remaining: {remaining:.0f} min')
    print(f'Valid: {remaining > 0}')
except Exception as ex:
    print(f'Error: {ex}')
" 2>&1
echo ""
echo "=== Last 20 bot.log ==="
tail -20 logs/bot.log 2>/dev/null || echo "No bot.log"
