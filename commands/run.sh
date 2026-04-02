#!/bin/bash
# Trigger: v122 - Deploy token fix + restart
cd /root/MT5-PropFirm-Bot
source .env 2>/dev/null

echo "=== DEPLOY v122 ==="
date -u

# 1. Update changed files from branch
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "claude/update-current-status-enwJV")
git fetch origin claude/update-current-status-enwJV 2>/dev/null
for f in futures_bot/core/tradovate_client.py futures_bot/bot.py; do
  git show origin/claude/update-current-status-enwJV:$f > $f 2>/dev/null && echo "Updated $f"
done

# 2. Permanent wrapper
cat > /usr/local/bin/start-futures-bot.sh << 'W'
#!/bin/bash
cd /root/MT5-PropFirm-Bot
export PYTHONPATH=/root/MT5-PropFirm-Bot
exec /usr/bin/python3 -m futures_bot.bot
W
chmod +x /usr/local/bin/start-futures-bot.sh

# 3. Service
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

# 4. Dirs
mkdir -p status logs configs

# 5. Restart
systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null
systemctl stop futures-bot 2>/dev/null
sleep 2
systemctl start futures-bot
echo "Bot started"
sleep 20

# 6. Status
STATUS=$(systemctl is-active futures-bot)
BOTLOG=$(tail -25 logs/bot.log 2>/dev/null)
echo "Service: $STATUS"
echo "$BOTLOG"

# 7. Telegram
MSG="Bot v122 - Token Fix
Service: ${STATUS}
$(date -u '+%Y-%m-%d %H:%M UTC')
---
${BOTLOG}"
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_CHAT_ID}" \
  -d text="${MSG:0:4000}" > /dev/null 2>&1

echo "=== END ==="
