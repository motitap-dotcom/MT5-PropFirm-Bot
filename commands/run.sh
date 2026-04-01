#!/bin/bash
# Trigger: v104 - Token + restart + send result to Telegram
cd /root/MT5-PropFirm-Bot
source .env 2>/dev/null

RESULT=""
log() { RESULT="${RESULT}${1}\n"; echo "$1"; }

log "=== FIX v104 ==="
log "Time: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

systemctl stop futures-bot 2>/dev/null
mkdir -p configs logs

# Save token
echo '{"access_token":"eyJraWQiOiIyOCIsImFsZyI6IkVkRFNBIn0.eyJzdWIiOiI3MTg1OTg3IiwiZXhwIjoxNzc0OTg0NTkxLCJqdGkiOiItNDEwNDg0MjU2NTUyMzY3MDkxOC0tNDA4ODI1MTkxMjA3MTkxMzUzOCIsInBocyI6LTE0OTM4NzI5MDQsImVtYWlsIjoibW90aXRhcEBnbWFpbC5jb20ifQ.yj04GEOYGG5fHmtMi0301jeeh6J3cNzIQk-CmbiR22_cSw0oQNLCBdegST6zryM90FrSvxbY19SCUKzcdPIdDA","md_access_token":"eyJraWQiOiIyOCIsImFsZyI6IkVkRFNBIn0.eyJzdWIiOiI3MTg1OTg3IiwiZXhwIjoxNzc0OTg0NTkxLCJqdGkiOiItNDEwNDg0MjU2NTUyMzY3MDkxOC0tNDA4ODI1MTkxMjA3MTkxMzUzOCIsInBocyI6LTE0OTM4NzI5MDQsImVtYWlsIjoibW90aXRhcEBnbWFpbC5jb20ifQ.yj04GEOYGG5fHmtMi0301jeeh6J3cNzIQk-CmbiR22_cSw0oQNLCBdegST6zryM90FrSvxbY19SCUKzcdPIdDA","expiry":9999999999}' > configs/.tradovate_token.json
log "Token saved"

# Update service to use global python
printf '[Unit]\nDescription=TradeDay Futures Trading Bot\nAfter=network.target\n\n[Service]\nType=simple\nWorkingDirectory=/root/MT5-PropFirm-Bot\nExecStart=/usr/bin/python3 -m futures_bot.bot\nRestart=on-failure\nRestartSec=60\nEnvironment=PYTHONUNBUFFERED=1\nEnvironmentFile=/root/MT5-PropFirm-Bot/.env\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/futures-bot.service
log "Service updated (global python)"

systemctl daemon-reload
systemctl start futures-bot
log "Bot started"

sleep 12
STATUS=$(systemctl is-active futures-bot)
log "Service: $STATUS"
BOTLOG=$(tail -15 logs/bot.log 2>/dev/null)
log "$BOTLOG"

# Send to Telegram
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_CHAT_ID}" \
  -d text="$(echo -e "$RESULT" | head -c 4000)" \
  -d parse_mode="" > /dev/null 2>&1

echo "=== Sent to Telegram ==="
