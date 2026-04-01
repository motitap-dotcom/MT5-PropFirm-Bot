#!/bin/bash
# Trigger: v103 - Quick token + restart via normal git
cd /root/MT5-PropFirm-Bot
echo "=== QUICK FIX v103 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

systemctl stop futures-bot 2>/dev/null
mkdir -p configs logs

# Save token
echo '{"access_token":"eyJraWQiOiIyOCIsImFsZyI6IkVkRFNBIn0.eyJzdWIiOiI3MTg1OTg3IiwiZXhwIjoxNzc0OTg0NTkxLCJqdGkiOiItNDEwNDg0MjU2NTUyMzY3MDkxOC0tNDA4ODI1MTkxMjA3MTkxMzUzOCIsInBocyI6LTE0OTM4NzI5MDQsImVtYWlsIjoibW90aXRhcEBnbWFpbC5jb20ifQ.yj04GEOYGG5fHmtMi0301jeeh6J3cNzIQk-CmbiR22_cSw0oQNLCBdegST6zryM90FrSvxbY19SCUKzcdPIdDA","md_access_token":"eyJraWQiOiIyOCIsImFsZyI6IkVkRFNBIn0.eyJzdWIiOiI3MTg1OTg3IiwiZXhwIjoxNzc0OTg0NTkxLCJqdGkiOiItNDEwNDg0MjU2NTUyMzY3MDkxOC0tNDA4ODI1MTkxMjA3MTkxMzUzOCIsInBocyI6LTE0OTM4NzI5MDQsImVtYWlsIjoibW90aXRhcEBnbWFpbC5jb20ifQ.yj04GEOYGG5fHmtMi0301jeeh6J3cNzIQk-CmbiR22_cSw0oQNLCBdegST6zryM90FrSvxbY19SCUKzcdPIdDA","expiry":9999999999}' > configs/.tradovate_token.json
echo "Token saved"

# Update service to use global python
printf '[Unit]\nDescription=TradeDay Futures Trading Bot\nAfter=network.target\n\n[Service]\nType=simple\nWorkingDirectory=/root/MT5-PropFirm-Bot\nExecStart=/usr/bin/python3 -m futures_bot.bot\nRestart=on-failure\nRestartSec=60\nEnvironment=PYTHONUNBUFFERED=1\nEnvironmentFile=/root/MT5-PropFirm-Bot/.env\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/futures-bot.service
echo "Service updated"

systemctl daemon-reload
systemctl start futures-bot
echo "Bot started"

sleep 10
echo ""
echo "Service: $(systemctl is-active futures-bot)"
tail -15 logs/bot.log 2>/dev/null
journalctl -u futures-bot --no-pager -n 5 2>&1
echo "=== END ==="
