#!/bin/bash
# Trigger: v103 - Copy token + fix service (NO restart - do separately)
cd /root/MT5-PropFirm-Bot

echo "=== Fix v103 (no restart) ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"

# 1. Copy token
echo ""
echo "=== Token ==="
if [ -f /root/tradovate-bot/.tradovate_token.json ]; then
    cp /root/tradovate-bot/.tradovate_token.json configs/.tradovate_token.json
    echo "Copied from Tradovate-Bot!"
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
    echo "NOT FOUND at /root/tradovate-bot/.tradovate_token.json"
    ls -la /root/tradovate-bot/*.json /root/tradovate-bot/.*.json 2>/dev/null
fi

# 2. Write .env
echo ""
echo "=== .env ==="
if [ -n "${TRADOVATE_USER}" ]; then
    cat > .env << ENVEOF
TRADOVATE_USER=${TRADOVATE_USER}
TRADOVATE_PASS=${TRADOVATE_PASS}
TRADOVATE_ACCESS_TOKEN=${TRADOVATE_ACCESS_TOKEN}
TELEGRAM_TOKEN=${TELEGRAM_TOKEN}
TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
ENVEOF
    echo "Written ($(wc -l < .env) lines)"
fi

# 3. Fix service with PYTHONPATH
echo ""
echo "=== Service ==="
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
echo "Service file updated"

# 4. Stop bot (will restart automatically via Restart=on-failure after output is committed)
echo ""
echo "=== Stopping bot (auto-restart in 30s) ==="
systemctl stop futures-bot 2>/dev/null
echo "Stopped. Will auto-restart in 30s with new token."

echo ""
echo "=== Current status ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "Token file: $([ -f configs/.tradovate_token.json ] && echo 'EXISTS' || echo 'MISSING')"
echo ".env: $([ -f .env ] && echo 'EXISTS' || echo 'MISSING')"
