#!/bin/bash
# Trigger: v110 - Fix service permanently with PYTHONPATH
cd /root/MT5-PropFirm-Bot
echo "=== PERMANENT FIX v110 ==="
date -u
echo ""

systemctl stop futures-bot 2>/dev/null
systemctl reset-failed futures-bot 2>/dev/null

# Save token
mkdir -p configs logs
echo '{"access_token":"eyJraWQiOiIyOCIsImFsZyI6IkVkRFNBIn0.eyJzdWIiOiI3MTg1OTg3IiwiZXhwIjoxNzc0OTg0NTkxLCJqdGkiOiItNDEwNDg0MjU2NTUyMzY3MDkxOC0tNDA4ODI1MTkxMjA3MTkxMzUzOCIsInBocyI6LTE0OTM4NzI5MDQsImVtYWlsIjoibW90aXRhcEBnbWFpbC5jb20ifQ.yj04GEOYGG5fHmtMi0301jeeh6J3cNzIQk-CmbiR22_cSw0oQNLCBdegST6zryM90FrSvxbY19SCUKzcdPIdDA","md_access_token":"eyJraWQiOiIyOCIsImFsZyI6IkVkRFNBIn0.eyJzdWIiOiI3MTg1OTg3IiwiZXhwIjoxNzc0OTg0NTkxLCJqdGkiOiItNDEwNDg0MjU2NTUyMzY3MDkxOC0tNDA4ODI1MTkxMjA3MTkxMzUzOCIsInBocyI6LTE0OTM4NzI5MDQsImVtYWlsIjoibW90aXRhcEBnbWFpbC5jb20ifQ.yj04GEOYGG5fHmtMi0301jeeh6J3cNzIQk-CmbiR22_cSw0oQNLCBdegST6zryM90FrSvxbY19SCUKzcdPIdDA","expiry":9999999999}' > configs/.tradovate_token.json

# Write bulletproof service file with explicit PYTHONPATH
cat > /etc/systemd/system/futures-bot.service << 'EOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=/bin/bash -c 'cd /root/MT5-PropFirm-Bot && PYTHONPATH=/root/MT5-PropFirm-Bot /usr/bin/python3 -m futures_bot.bot'
Restart=on-failure
RestartSec=60
Environment=PYTHONUNBUFFERED=1
Environment=PYTHONPATH=/root/MT5-PropFirm-Bot
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
EOF

echo "Service file written"
cat /etc/systemd/system/futures-bot.service

systemctl daemon-reload
systemctl start futures-bot
echo "Bot started"

sleep 15
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo ""
tail -20 logs/bot.log 2>/dev/null || echo "No log"
journalctl -u futures-bot --no-pager -n 8 2>&1
echo "=== END ==="
