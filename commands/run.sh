#!/bin/bash
# Trigger: v96 - Install full protection stack
cd /root/MT5-PropFirm-Bot

echo "=== FULL INSTALL v96 - $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="

# Write .env
if [ -n "$TRADOVATE_USER" ]; then
    echo "TRADOVATE_USER=$TRADOVATE_USER" > .env
    echo "TRADOVATE_PASS=$TRADOVATE_PASS" >> .env
    echo "TRADOVATE_ACCESS_TOKEN=$TRADOVATE_ACCESS_TOKEN" >> .env
    echo "TELEGRAM_TOKEN=$TELEGRAM_TOKEN" >> .env
    echo "TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID" >> .env
fi

# Run the full install
bash scripts/install_bot.sh 2>&1

# Restart bot with latest code
systemctl restart futures-bot
sleep 10

echo ""
echo "--- Service status ---"
systemctl is-active futures-bot
echo ""
echo "--- Watchdog timer ---"
systemctl is-active futures-bot-watchdog.timer
echo ""
echo "--- Bot log (last 15 lines) ---"
tail -15 logs/bot.log 2>/dev/null || echo "No log yet"
echo ""
echo "--- Disk space ---"
df -h / | tail -1
echo ""
echo "=== DONE ==="
