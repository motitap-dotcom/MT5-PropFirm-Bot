#!/bin/bash
# Trigger: v98 - Install deps + write .env + fix service + restart
cd /root/MT5-PropFirm-Bot

echo "=== Fix & Restart v98 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "Branch: $(git branch --show-current 2>/dev/null)"
echo "Commit: $(git log -1 --oneline 2>/dev/null)"

# 1. Install dependencies
echo ""
echo "=== Installing deps ==="
pip3 install aiohttp websockets python-dotenv numpy 2>&1 | tail -5
echo "Verify: $(python3 -c 'import aiohttp,websockets; print("OK")' 2>&1)"

# 2. Write .env from workflow secrets
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
    echo ".env written"
    TOKEN_VAL=$(grep "TRADOVATE_ACCESS_TOKEN=" .env | cut -d= -f2)
    [ -z "$TOKEN_VAL" ] && echo "WARNING: TRADOVATE_ACCESS_TOKEN is EMPTY!" || echo "TOKEN: SET (${#TOKEN_VAL} chars)"
else
    echo "No secrets from workflow"
fi

# 3. Fix service + restart
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
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SVCEOF
systemctl daemon-reload
systemctl stop futures-bot 2>/dev/null
sleep 2
systemctl start futures-bot
sleep 10
echo "Status: $(systemctl is-active futures-bot)"

echo ""
echo "=== Logs ==="
journalctl -u futures-bot --no-pager -n 15 2>&1
