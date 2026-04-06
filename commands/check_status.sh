#!/bin/bash
# commands/check_status.sh - Simple status check that pushes output back
# Used by vps-command workflow
cd /root/MT5-PropFirm-Bot
mkdir -p logs status

echo "=== Bot Status Report ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo ""

# Service status
STATUS=$(systemctl is-active futures-bot 2>/dev/null || echo "unknown")
echo "Service: ${STATUS}"
UPTIME=$(systemctl show futures-bot --property=ActiveEnterTimestamp --value 2>/dev/null)
echo "Running since: ${UPTIME}"
echo ""

# System resources
echo "=== System ==="
echo "Disk: $(df -h / | tail -1 | awk '{print $5}')"
echo "Memory: $(free -m | awk '/^Mem:/{printf "%dMB/%dMB (%.0f%%)", $3, $2, $3/$2*100}')"
echo ""

# Git info
echo "=== Git ==="
echo "Branch: $(git branch --show-current 2>/dev/null)"
echo "Commit: $(git log -1 --format='%h %s' 2>/dev/null)"
echo ""

# Token info
echo "=== Auth ==="
if [ -f configs/.tradovate_token.json ]; then
    echo "Token file: EXISTS"
    python3 -c "
import json
from datetime import datetime, timezone
with open('configs/.tradovate_token.json') as f:
    t = json.load(f)
exp = t.get('expirationTime','')
print(f'Expires: {exp}')
if exp:
    from datetime import datetime, timezone
    e = datetime.fromisoformat(exp.replace('Z','+00:00'))
    remaining = (e - datetime.now(timezone.utc)).total_seconds() / 60
    print(f'Remaining: {remaining:.0f} min')
    print(f'Valid: {remaining > 0}')
" 2>/dev/null || echo "Token parse error"
else
    echo "Token file: MISSING"
fi
echo ""

# .env check
echo "=== Environment ==="
if [ -f .env ]; then
    echo ".env: EXISTS ($(wc -l < .env) lines)"
else
    echo ".env: MISSING"
fi
echo ""

# Bot logs
echo "=== Journal Logs (last 20 lines) ==="
journalctl -u futures-bot --no-pager -n 20 2>&1
echo ""

echo "=== Bot Log (last 20 lines) ==="
tail -20 logs/bot.log 2>/dev/null || echo "No bot.log found"
echo ""

# Status JSON
echo "=== status.json ==="
cat status/status.json 2>/dev/null || echo "No status.json"
