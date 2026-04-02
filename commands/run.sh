#!/bin/bash
# Trigger: v121 - Fix bot + send status to Telegram
cd /root/MT5-PropFirm-Bot
source .env 2>/dev/null

echo "=== FIX v121 ==="
date -u

# 1. Permanent wrapper
cat > /usr/local/bin/start-futures-bot.sh << 'W'
#!/bin/bash
cd /root/MT5-PropFirm-Bot
export PYTHONPATH=/root/MT5-PropFirm-Bot
exec /usr/bin/python3 -m futures_bot.bot
W
chmod +x /usr/local/bin/start-futures-bot.sh

# 2. Service file
cat > /etc/systemd/system/futures-bot.service << 'S'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/start-futures-bot.sh
Restart=on-failure
RestartSec=60
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
S

# 3. Dirs
mkdir -p status logs configs

# 4. Restart
systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null
systemctl stop futures-bot 2>/dev/null
sleep 2
systemctl start futures-bot
echo "Bot started"
sleep 20

# 5. Collect status
STATUS=$(systemctl is-active futures-bot)
LOGLINES=$(tail -25 logs/bot.log 2>/dev/null)
TOKEN_INFO=$(cat configs/.tradovate_token.json 2>/dev/null | head -1 | cut -c1-60)

echo "Service: $STATUS"
echo "$LOGLINES"

# 6. Send to Telegram
MSG="Bot Status v121
Service: ${STATUS}
$(date -u '+%Y-%m-%d %H:%M UTC')
---
${LOGLINES}"

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_CHAT_ID}" \
  -d text="${MSG:0:4000}" > /dev/null 2>&1

echo "=== Sent to Telegram ==="
