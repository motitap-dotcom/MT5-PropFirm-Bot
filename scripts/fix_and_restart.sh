#!/bin/bash
echo "=== Comprehensive Fix & Restart ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot

# Preserve token and .env
cp configs/.tradovate_token.json /tmp/.tradovate_token_backup.json 2>/dev/null || true
cp .env /tmp/.env_backup 2>/dev/null || true

# Pull latest from main
git fetch origin main
git reset --hard origin/main
echo "Code: $(git log -1 --oneline)"

# Restore token and .env
cp /tmp/.tradovate_token_backup.json configs/.tradovate_token.json 2>/dev/null || true
cp /tmp/.env_backup .env 2>/dev/null || true

# Ensure required directories exist
mkdir -p status logs configs

# Verify .env has required variables
echo ""
echo "--- .env check ---"
for var in TRADOVATE_USER TRADOVATE_PASS TELEGRAM_TOKEN TELEGRAM_CHAT_ID; do
    if grep -q "^${var}=" .env 2>/dev/null; then
        echo "$var: SET"
    else
        echo "$var: MISSING!"
    fi
done

# Check token file
echo ""
echo "--- Token check ---"
if [ -f configs/.tradovate_token.json ]; then
    echo "Token file exists ($(stat -c%s configs/.tradovate_token.json) bytes)"
    python3 -c "
import json
t = json.load(open('configs/.tradovate_token.json'))
print(f'Token expires: {t.get(\"expirationTime\", \"unknown\")}')
print(f'Has accessToken: {bool(t.get(\"accessToken\"))}')
" 2>/dev/null || echo "Could not parse token file"
else
    echo "No token file - Playwright will need to get one"
fi

# Install/verify Playwright
echo ""
echo "--- Playwright check ---"
python3 -c "from playwright.sync_api import sync_playwright; print('Playwright: OK')" 2>/dev/null || {
    echo "Installing Playwright..."
    pip3 install playwright 2>&1 | tail -1
    python3 -m playwright install chromium 2>&1 | tail -1
}

# Write correct service file
cat > /etc/systemd/system/futures-bot.service << 'SVCEOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=/usr/bin/python3 -m futures_bot.bot
Restart=on-failure
RestartSec=60
Environment=PYTHONUNBUFFERED=1
Environment=PYTHONPATH=/root/MT5-PropFirm-Bot
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null
systemctl restart futures-bot
sleep 5

echo ""
echo "--- Result ---"
echo "Status: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
tail -10 logs/bot.log 2>/dev/null || echo "No log yet"
