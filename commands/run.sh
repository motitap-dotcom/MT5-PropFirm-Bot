#!/bin/bash
# Trigger: v14 - restart bot with latest code + verify
echo "=== Restart Bot with Latest Config ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"

cd /root/MT5-PropFirm-Bot

# Update .env
python3 << 'PYEOF'
import os
token = os.environ.get('TRADOVATE_ACCESS_TOKEN', '').strip()
user = os.environ.get('TRADOVATE_USER', '')
passwd = os.environ.get('TRADOVATE_PASS', '')
tg_token = os.environ.get('TELEGRAM_TOKEN', '')
tg_chat = os.environ.get('TELEGRAM_CHAT_ID', '')
with open('/root/MT5-PropFirm-Bot/.env', 'w') as f:
    f.write(f'TRADOVATE_USER={user}\n')
    f.write(f'TRADOVATE_PASS={passwd}\n')
    f.write(f'TRADOVATE_ACCESS_TOKEN={token}\n')
    f.write(f'TELEGRAM_TOKEN={tg_token}\n')
    f.write(f'TELEGRAM_CHAT_ID={tg_chat}\n')
print(f".env updated (token={len(token)} chars)")
PYEOF

# Show config
echo ""
echo "--- Bot Config ---"
python3 -c "
import json
with open('configs/bot_config.json') as f:
    c = json.load(f)
print(f'Symbols: {c[\"symbols\"]}')
print(f'Organization: {c.get(\"organization\",\"\")}')
print(f'Max daily trades: {c[\"guardian\"][\"max_daily_trades\"]}')
print(f'Max daily loss: \${c[\"guardian\"][\"max_daily_loss\"]}')
print(f'Max risk/trade: \${c[\"risk\"][\"max_risk_per_trade\"]}')
print(f'Max positions: {c[\"risk\"][\"max_positions\"]}')
print(f'Max contracts/trade: {c[\"risk\"][\"max_contracts_per_trade\"]}')
"

# Restart bot
echo ""
echo "--- Restarting bot ---"
systemctl stop futures-bot 2>/dev/null
sleep 2
systemctl start futures-bot
sleep 5

echo ""
echo "--- Service Status ---"
systemctl is-active futures-bot
systemctl status futures-bot --no-pager 2>&1 | head -15

echo ""
echo "--- Bot Logs ---"
tail -20 /root/MT5-PropFirm-Bot/logs/bot.log 2>/dev/null || journalctl -u futures-bot --no-pager -n 20

echo ""
echo "--- Token Status ---"
python3 -c "
import json, time
try:
    with open('configs/.tradovate_token.json') as f:
        t = json.load(f)
    exp = t.get('expiry', 0)
    remaining = exp - time.time()
    print(f'Token env: {t.get(\"environment\",\"?\")}')
    print(f'Token expires in: {remaining/3600:.1f} hours')
    print(f'Org: {t.get(\"organization\",\"?\")}')
except:
    print('No token file found')
"

echo ""
echo "=== Done ==="
