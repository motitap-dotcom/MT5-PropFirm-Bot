#!/bin/bash
# Trigger: v102 - Copy token from working Tradovate-Bot + fix PYTHONPATH + restart
cd /root/MT5-PropFirm-Bot

echo "=== Full Fix v102 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"

# 1. Copy token from the working Tradovate-Bot
echo ""
echo "=== Copying token from Tradovate-Bot ==="
if [ -f /root/tradovate-bot/.tradovate_token.json ]; then
    cp /root/tradovate-bot/.tradovate_token.json configs/.tradovate_token.json
    echo "Token copied!"
    python3 -c "
import json
from datetime import datetime, timezone
with open('configs/.tradovate_token.json') as f:
    t = json.load(f)
exp = t.get('expirationTime','')
print(f'Expires: {exp}')
if exp:
    e = datetime.fromisoformat(exp.replace('Z','+00:00'))
    remaining = (e - datetime.now(timezone.utc)).total_seconds() / 60
    print(f'Remaining: {remaining:.0f} min')
    print(f'Valid: {remaining > 0}')
" 2>&1
else
    echo "Token file not found at /root/tradovate-bot/.tradovate_token.json"
    echo "Checking other locations..."
    find /root/tradovate-bot -name "*.tradovate_token*" -o -name "*token*.json" 2>/dev/null | head -5
fi

# 2. Write .env from secrets
echo ""
echo "=== Writing .env ==="
if [ -n "${TRADOVATE_USER}" ]; then
    cat > .env << ENVEOF
TRADOVATE_USER=${TRADOVATE_USER}
TRADOVATE_PASS=${TRADOVATE_PASS}
TRADOVATE_ACCESS_TOKEN=${TRADOVATE_ACCESS_TOKEN}
TELEGRAM_TOKEN=${TELEGRAM_TOKEN}
TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
ENVEOF
    echo ".env written ($(wc -l < .env) lines)"
fi

# 3. Fix service with PYTHONPATH
echo ""
echo "=== Fixing service ==="
cat > /etc/systemd/system/futures-bot.service << 'SVCEOF'
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
Environment=PYTHONPATH=/root/MT5-PropFirm-Bot
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SVCEOF
systemctl daemon-reload
echo "Service file updated with PYTHONPATH"

# 4. Stop and start fresh
echo ""
echo "=== Restarting bot ==="
systemctl stop futures-bot 2>/dev/null
sleep 3
systemctl start futures-bot
sleep 15

STATUS=$(systemctl is-active futures-bot)
echo "Service: $STATUS"

# 5. Show results
echo ""
echo "=== Journal (last 20) ==="
journalctl -u futures-bot --no-pager -n 20 2>&1

echo ""
echo "=== Bot log (last 15) ==="
tail -15 logs/bot.log 2>/dev/null || echo "No bot.log"
