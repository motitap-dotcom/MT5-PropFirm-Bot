#!/bin/bash
# Trigger: v123 - Check browser auth result
cd /root/MT5-PropFirm-Bot
echo "=== Check Auth Result v123 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"

echo ""
echo "=== Browser auth log ==="
cat /tmp/browser_auth.log 2>/dev/null || echo "No log"

echo ""
echo "=== Browser auth stdout ==="
tail -20 /tmp/browser_auth_stdout.log 2>/dev/null || echo "No stdout"

echo ""
echo "=== Token file ==="
if [ -f configs/.tradovate_token.json ]; then
    python3 -c "
import json
from datetime import datetime, timezone
with open('configs/.tradovate_token.json') as f:
    t = json.load(f)
print(f'Account: {t.get(\"accountSpec\",\"?\")}')
exp = t.get('expirationTime','')
print(f'Expires: {exp}')
if exp:
    e = datetime.fromisoformat(exp.replace('Z','+00:00'))
    remaining = (e - datetime.now(timezone.utc)).total_seconds() / 60
    print(f'Remaining: {remaining:.0f} min')
" 2>&1
else
    echo "No token file"
fi

echo ""
echo "=== Process check ==="
pgrep -f "get_tradeday_token" && echo "Still running" || echo "Finished"
