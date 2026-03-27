#!/bin/bash
# Trigger: v13 - START THE BOT
echo "=== Starting TradeDay Futures Bot ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"

cd /root/MT5-PropFirm-Bot

# Update .env with all secrets
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
print(f".env updated (token_len={len(token)})")
PYEOF

# Ensure systemd service exists
cat > /etc/systemd/system/futures-bot.service << 'SERVICEEOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=/usr/bin/python3 -m futures_bot.bot
Restart=on-failure
RestartSec=30
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable futures-bot

# Stop if running, then start
systemctl stop futures-bot 2>/dev/null
sleep 2
systemctl start futures-bot

sleep 3

echo ""
echo "--- Bot Status ---"
systemctl status futures-bot --no-pager 2>&1 | head -15
echo ""
echo "--- Last 10 log lines ---"
tail -10 /root/MT5-PropFirm-Bot/logs/bot.log 2>/dev/null || journalctl -u futures-bot --no-pager -n 10
echo ""
echo "=== Done ==="
