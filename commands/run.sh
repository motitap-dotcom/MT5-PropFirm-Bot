#!/bin/bash
# Trigger: v98 - Set fresh token and restart bot
cd /root/MT5-PropFirm-Bot

echo "=== SET TOKEN + RESTART ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

# Kill any stuck chromium/browser processes
pkill -f chromium 2>/dev/null || true
pkill -f playwright 2>/dev/null || true

# Stop bot
systemctl stop futures-bot 2>/dev/null
echo "Bot stopped"

# Save the fresh token
mkdir -p configs
cat > configs/.tradovate_token.json << 'TOKENEOF'
{
  "access_token": "eyJraWQiOiIyOCIsImFsZyI6IkVkRFNBIn0.eyJzdWIiOiI3MTg1OTg3IiwiZXhwIjoxNzc0OTg0NTkxLCJqdGkiOiItNDEwNDg0MjU2NTUyMzY3MDkxOC0tNDA4ODI1MTkxMjA3MTkxMzUzOCIsInBocyI6LTE0OTM4NzI5MDQsImVtYWlsIjoibW90aXRhcEBnbWFpbC5jb20ifQ.yj04GEOYGG5fHmtMi0301jeeh6J3cNzIQk-CmbiR22_cSw0oQNLCBdegST6zryM90FrSvxbY19SCUKzcdPIdDA",
  "md_access_token": "eyJraWQiOiIyOCIsImFsZyI6IkVkRFNBIn0.eyJzdWIiOiI3MTg1OTg3IiwiZXhwIjoxNzc0OTg0NTkxLCJqdGkiOiItNDEwNDg0MjU2NTUyMzY3MDkxOC0tNDA4ODI1MTkxMjA3MTkxMzUzOCIsInBocyI6LTE0OTM4NzI5MDQsImVtYWlsIjoibW90aXRhcEBnbWFpbC5jb20ifQ.yj04GEOYGG5fHmtMi0301jeeh6J3cNzIQk-CmbiR22_cSw0oQNLCBdegST6zryM90FrSvxbY19SCUKzcdPIdDA",
  "expiry": 9999999999,
  "saved_at": "2026-03-31T18:00:00Z"
}
TOKENEOF

echo "Token saved to configs/.tradovate_token.json"
echo ""

# Setup venv if needed
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

# Quick install check
venv/bin/python3 -c "from futures_bot.core.tradovate_client import TradovateClient; print('Import OK')" 2>&1

# Restart bot
systemctl daemon-reload
systemctl start futures-bot
echo "Bot started"
echo ""

# Wait for bot to initialize
sleep 20

echo "=== Service Status ==="
systemctl is-active futures-bot
echo ""

echo "=== Bot Log (last 25 lines) ==="
tail -25 logs/bot.log 2>/dev/null || echo "No log yet"
echo ""

echo "=== Journal ==="
journalctl -u futures-bot --no-pager -n 15 2>&1
echo ""

echo "=== END ==="
