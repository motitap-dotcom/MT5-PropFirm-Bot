#!/bin/bash
# Trigger: v97 - Fix deps + restart bot
cd /root/MT5-PropFirm-Bot

echo "=== Fix & Restart ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"

# 1. Switch to main branch properly
echo ""
echo "=== Switching to main ==="
git fetch origin main 2>&1
git checkout -B main origin/main 2>&1
echo "Branch: $(git branch --show-current)"
echo "Commit: $(git log -1 --oneline)"

# 2. Install dependencies for system python3
echo ""
echo "=== Installing dependencies ==="
pip3 install -r requirements.txt 2>&1 | tail -10
echo ""
echo "Verify imports:"
python3 -c "import aiohttp; print(f'  aiohttp: {aiohttp.__version__}')" 2>&1
python3 -c "import websockets; print(f'  websockets: {websockets.__version__}')" 2>&1
python3 -c "import futures_bot; print('  futures_bot: OK')" 2>&1

# 3. Check .env
echo ""
echo "=== Environment ==="
if [ -f .env ]; then
    echo ".env exists ($(wc -l < .env) lines)"
    grep -c "TRADOVATE_ACCESS_TOKEN" .env > /dev/null && echo "TRADOVATE_ACCESS_TOKEN: SET" || echo "TRADOVATE_ACCESS_TOKEN: MISSING"
    grep -c "TRADOVATE_USER" .env > /dev/null && echo "TRADOVATE_USER: SET" || echo "TRADOVATE_USER: MISSING"
    grep -c "TRADOVATE_PASS" .env > /dev/null && echo "TRADOVATE_PASS: SET" || echo "TRADOVATE_PASS: MISSING"
    grep -c "TELEGRAM_TOKEN" .env > /dev/null && echo "TELEGRAM_TOKEN: SET" || echo "TELEGRAM_TOKEN: MISSING"
else
    echo ".env MISSING!"
fi

# 4. Write fresh .env from workflow env vars (if available)
if [ -n "${TRADOVATE_USER}" ]; then
    echo ""
    echo "=== Writing fresh .env from secrets ==="
    cat > .env << ENVEOF
TRADOVATE_USER=${TRADOVATE_USER}
TRADOVATE_PASS=${TRADOVATE_PASS}
TRADOVATE_ACCESS_TOKEN=${TRADOVATE_ACCESS_TOKEN}
TELEGRAM_TOKEN=${TELEGRAM_TOKEN}
TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
ENVEOF
    echo ".env written ($(wc -l < .env) lines)"
    # Check if token is actually set
    TOKEN_VAL=$(grep "TRADOVATE_ACCESS_TOKEN=" .env | cut -d= -f2)
    if [ -z "$TOKEN_VAL" ]; then
        echo "WARNING: TRADOVATE_ACCESS_TOKEN is EMPTY in secrets!"
    else
        echo "TRADOVATE_ACCESS_TOKEN: SET (${#TOKEN_VAL} chars)"
    fi
fi

# 5. Fix service file
echo ""
echo "=== Fixing service file ==="
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
echo "Service file updated"

# 6. Restart bot
echo ""
echo "=== Restarting bot ==="
systemctl stop futures-bot 2>/dev/null
sleep 2
systemctl start futures-bot
sleep 15

STATUS=$(systemctl is-active futures-bot)
echo "Service: $STATUS"

if [ "$STATUS" = "active" ]; then
    echo "BOT IS RUNNING!"
    PID=$(systemctl show futures-bot --property=MainPID --value)
    echo "PID: $PID"
fi

echo ""
echo "=== Recent logs ==="
journalctl -u futures-bot --no-pager -n 30 2>&1

echo ""
echo "=== Bot log ==="
tail -20 logs/bot.log 2>/dev/null || echo "No bot.log yet"
