#!/bin/bash
# Trigger: v22 - heredoc without quotes to pass env vars
echo "=== Bot Status Check ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"

cd /root/MT5-PropFirm-Bot

# Fix git config for push
git config user.email "bot@tradeday.com"
git config user.name "TradeDay Bot"

# Update .env
python3 -c "
import os
token = os.environ.get('TRADOVATE_ACCESS_TOKEN', '').strip()
user = os.environ.get('TRADOVATE_USER', '')
passwd = os.environ.get('TRADOVATE_PASS', '')
tg_token = os.environ.get('TELEGRAM_TOKEN', '')
tg_chat = os.environ.get('TELEGRAM_CHAT_ID', '')
with open('.env', 'w') as f:
    f.write(f'TRADOVATE_USER={user}\n')
    f.write(f'TRADOVATE_PASS={passwd}\n')
    f.write(f'TRADOVATE_ACCESS_TOKEN={token}\n')
    f.write(f'TELEGRAM_TOKEN={tg_token}\n')
    f.write(f'TELEGRAM_CHAT_ID={tg_chat}\n')
print(f'.env updated (token={len(token)} chars)')
"

# Show config
echo ""
echo "--- Config ---"
python3 -c "
import json
with open('configs/bot_config.json') as f:
    c = json.load(f)
print(f'Symbols: {c[\"symbols\"]}')
print(f'Organization: {c.get(\"organization\",\"\")}')
print(f'Max daily trades: {c[\"guardian\"][\"max_daily_trades\"]}')
print(f'Max daily loss: \${c[\"guardian\"][\"max_daily_loss\"]}')
print(f'Max daily profit: \${c[\"guardian\"][\"max_daily_profit\"]}')
print(f'Max risk/trade: \${c[\"risk\"][\"max_risk_per_trade\"]}')
"

# Restart bot
echo ""
echo "--- Restarting bot ---"
systemctl stop futures-bot 2>/dev/null
sleep 2
systemctl start futures-bot
sleep 5

echo ""
echo "--- Service ---"
systemctl is-active futures-bot

echo ""
echo "--- Logs (last 20 lines) ---"
tail -20 logs/bot.log 2>/dev/null || journalctl -u futures-bot --no-pager -n 20

echo ""
echo "--- Token ---"
python3 -c "
import json, time
try:
    with open('configs/.tradovate_token.json') as f:
        t = json.load(f)
    remaining = t.get('expiry', 0) - time.time()
    print(f'Environment: {t.get(\"environment\",\"?\")}')
    print(f'Org: {t.get(\"organization\",\"?\")}')
    print(f'Expires in: {remaining/3600:.1f} hours')
except Exception as e:
    print(f'Token file error: {e}')
"

echo ""
echo "=== Done ==="
