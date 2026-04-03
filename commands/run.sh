#!/bin/bash
# Trigger: live-status-v1
cd /root/MT5-PropFirm-Bot

echo "=== Bot Live Status ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "ET Time: $(TZ='America/New_York' date '+%H:%M %Z')"
echo ""

echo "=== Service ==="
systemctl is-active futures-bot
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Since: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""

echo "=== Last 40 Journal Lines ==="
journalctl -u futures-bot --no-pager -n 40
echo ""

echo "=== Token ==="
python3 -c "
import json, time
d = json.loads(open('configs/.tradovate_token.json').read())
exp = d.get('expiry', 0)
remaining = exp - time.time()
print(f'Remaining: {remaining/60:.0f} minutes')
print(f'Saved: {d.get(\"saved_at\", \"unknown\")}')
" 2>/dev/null || echo "No token"
echo ""

echo "=== Status JSON ==="
cat status/status.json 2>/dev/null || echo "No status file"
echo ""

echo "=== Bot Log (last 20 lines) ==="
tail -20 logs/bot.log 2>/dev/null || echo "No bot log"
echo ""

# Also create the status directory if missing
mkdir -p status logs
echo "=== DONE ==="
