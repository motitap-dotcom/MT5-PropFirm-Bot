#!/bin/bash
# Trigger: v36 - status check only
echo "=== Bot Status Check ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"

cd /root/MT5-PropFirm-Bot

echo ""
echo "--- Service Status ---"
systemctl is-active futures-bot 2>/dev/null || echo "Service not running"

echo ""
echo "--- Bot Process ---"
ps aux | grep -E '[p]ython.*bot' || echo "No bot process running"

echo ""
echo "--- Token Check ---"
python3 << 'PYEOF'
import json, time, os
try:
    with open('configs/.tradovate_token.json') as f:
        t = json.load(f)
    remaining = t.get('expiry', 0) - time.time()
    print(f"Token expires in: {remaining/3600:.1f} hours")
    if remaining < 0:
        print("TOKEN IS EXPIRED!")
    elif remaining < 1:
        print("TOKEN EXPIRING SOON!")
    print(f"Organization: {t.get('organization','?')}")
except Exception as e:
    print(f"Token file error: {e}")

# Show .env info
if os.path.exists('.env'):
    with open('.env') as f:
        lines = [l for l in f.readlines() if '=' in l and not l.startswith('#')]
    token_len = 0
    for l in lines:
        if 'ACCESS_TOKEN' in l:
            token_len = len(l.split('=',1)[1].strip())
    print(f"\n.env: {len(lines)} vars, token={token_len} chars")
else:
    print("\n.env NOT FOUND!")
PYEOF

echo ""
echo "--- Config ---"
python3 -c "
import json
with open('configs/bot_config.json') as f:
    c = json.load(f)
print(f'Symbols: {c[\"symbols\"]}')
print(f'Max daily trades: {c[\"guardian\"][\"max_daily_trades\"]}')
print(f'Max daily loss: \${c[\"guardian\"][\"max_daily_loss\"]}')
print(f'Max daily profit: \${c[\"guardian\"][\"max_daily_profit\"]}')
" 2>/dev/null

echo ""
echo "--- Logs (last 30) ---"
tail -30 logs/bot.log 2>/dev/null || echo "No log file"

echo ""
echo "--- status.json ---"
cat status/status.json 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "No status.json"

echo ""
echo "=== Done ==="
