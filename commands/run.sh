#!/bin/bash
# Trigger: v101 - Full fix: install deps + set token + restart
cd /root/MT5-PropFirm-Bot

echo "=== FULL FIX ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# Stop bot and kill stuck processes
systemctl stop futures-bot 2>/dev/null
pkill -f chromium 2>/dev/null || true
echo "Bot stopped"

# Make sure dirs exist
mkdir -p logs status configs

# Install deps globally
pip3 install -r requirements.txt 2>&1 | tail -3
python3 -m playwright install chromium --with-deps 2>&1 | tail -3

# Install deps in venv too
if [ -d venv ]; then
  venv/bin/pip install -r requirements.txt 2>&1 | tail -3
  venv/bin/python3 -m playwright install chromium --with-deps 2>&1 | tail -3
fi

# Verify imports
echo ""
echo "=== Import Check ==="
python3 -c "from futures_bot.core.tradovate_client import TradovateClient; print('Global python: OK')" 2>&1
test -d venv && venv/bin/python3 -c "from futures_bot.core.tradovate_client import TradovateClient; print('Venv python: OK')" 2>&1

# Save token
cat > configs/.tradovate_token.json << 'TOKENEOF'
{
  "access_token": "eyJraWQiOiIyOCIsImFsZyI6IkVkRFNBIn0.eyJzdWIiOiI3MTg1OTg3IiwiZXhwIjoxNzc0OTg0NTkxLCJqdGkiOiItNDEwNDg0MjU2NTUyMzY3MDkxOC0tNDA4ODI1MTkxMjA3MTkxMzUzOCIsInBocyI6LTE0OTM4NzI5MDQsImVtYWlsIjoibW90aXRhcEBnbWFpbC5jb20ifQ.yj04GEOYGG5fHmtMi0301jeeh6J3cNzIQk-CmbiR22_cSw0oQNLCBdegST6zryM90FrSvxbY19SCUKzcdPIdDA",
  "md_access_token": "eyJraWQiOiIyOCIsImFsZyI6IkVkRFNBIn0.eyJzdWIiOiI3MTg1OTg3IiwiZXhwIjoxNzc0OTg0NTkxLCJqdGkiOiItNDEwNDg0MjU2NTUyMzY3MDkxOC0tNDA4ODI1MTkxMjA3MTkxMzUzOCIsInBocyI6LTE0OTM4NzI5MDQsImVtYWlsIjoibW90aXRhcEBnbWFpbC5jb20ifQ.yj04GEOYGG5fHmtMi0301jeeh6J3cNzIQk-CmbiR22_cSw0oQNLCBdegST6zryM90FrSvxbY19SCUKzcdPIdDA",
  "expiry": 9999999999,
  "saved_at": "2026-03-31T19:30:00Z"
}
TOKENEOF
echo "Token saved"

# Fix systemd service - use global python (not venv) to avoid import issues
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
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SVCEOF
echo "Service file updated to use global python"

# Restart
systemctl daemon-reload
systemctl start futures-bot
echo "Bot started"

# Wait and check
sleep 20
echo ""
echo "=== Result ==="
echo "Service: $(systemctl is-active futures-bot)"
echo ""
tail -20 logs/bot.log 2>/dev/null || echo "No logs yet"
echo ""
journalctl -u futures-bot --no-pager -n 10 2>&1
echo ""
echo "=== END ==="
