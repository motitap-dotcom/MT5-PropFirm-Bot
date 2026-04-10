#!/bin/bash
echo "=== Fix & Restart v17 - Fix WS heartbeat + .closed attr ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot

# Show current code version
echo "Current: $(git log -1 --oneline)"
echo "Branch: $(git branch --show-current)"

# Ensure required directories exist
mkdir -p status logs configs

# Verify .env
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
    echo "Token file: exists ($(stat -c%s configs/.tradovate_token.json) bytes)"
else
    echo "Token file: MISSING (Playwright will get one)"
fi

# Verify Playwright
python3 -c "from playwright.sync_api import sync_playwright; print('Playwright: OK')" 2>/dev/null || {
    echo "Installing Playwright..."
    pip3 install playwright -q 2>&1 | tail -1
    python3 -m playwright install chromium 2>&1 | tail -1
}

# Verify key code fixes are present
echo ""
echo "--- Code verification ---"
echo "auth_cooldown: $(grep -c 'auth_cooldown' futures_bot/core/tradovate_client.py)"
echo "wait_for_selector: $(grep -c 'wait_for_selector' futures_bot/core/tradovate_client.py)"
echo "mkdir in status_writer: $(grep -c 'mkdir' futures_bot/core/status_writer.py)"

# Service file with PYTHONPATH
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

# Restart
systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null
systemctl restart futures-bot
sleep 8

echo ""
echo "--- Result ---"
echo "Status: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- First 15 log lines after restart ---"
tail -15 logs/bot.log 2>/dev/null
