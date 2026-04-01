#!/bin/bash
# Trigger: v108 - Reset failure counter + restart bot
cd /root/MT5-PropFirm-Bot
echo "=== RESTART v108 ==="
date -u
echo ""

# Reset systemd failure counter
systemctl reset-failed futures-bot 2>/dev/null
systemctl stop futures-bot 2>/dev/null

# Save fresh token
mkdir -p configs
echo '{"access_token":"eyJraWQiOiIyOCIsImFsZyI6IkVkRFNBIn0.eyJzdWIiOiI3MTg1OTg3IiwiZXhwIjoxNzc0OTg0NTkxLCJqdGkiOiItNDEwNDg0MjU2NTUyMzY3MDkxOC0tNDA4ODI1MTkxMjA3MTkxMzUzOCIsInBocyI6LTE0OTM4NzI5MDQsImVtYWlsIjoibW90aXRhcEBnbWFpbC5jb20ifQ.yj04GEOYGG5fHmtMi0301jeeh6J3cNzIQk-CmbiR22_cSw0oQNLCBdegST6zryM90FrSvxbY19SCUKzcdPIdDA","md_access_token":"eyJraWQiOiIyOCIsImFsZyI6IkVkRFNBIn0.eyJzdWIiOiI3MTg1OTg3IiwiZXhwIjoxNzc0OTg0NTkxLCJqdGkiOiItNDEwNDg0MjU2NTUyMzY3MDkxOC0tNDA4ODI1MTkxMjA3MTkxMzUzOCIsInBocyI6LTE0OTM4NzI5MDQsImVtYWlsIjoibW90aXRhcEBnbWFpbC5jb20ifQ.yj04GEOYGG5fHmtMi0301jeeh6J3cNzIQk-CmbiR22_cSw0oQNLCBdegST6zryM90FrSvxbY19SCUKzcdPIdDA","expiry":9999999999}' > configs/.tradovate_token.json

# Reload and start
systemctl daemon-reload
systemctl start futures-bot
echo "Bot started"

sleep 15
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "=== Log ==="
tail -20 logs/bot.log 2>/dev/null || echo "No log"
echo ""
echo "=== Journal ==="
journalctl -u futures-bot --no-pager -n 10 2>&1
echo "=== END ==="
