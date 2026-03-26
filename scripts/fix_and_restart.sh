#!/bin/bash
echo "=== TradeDay Futures Bot - Fix & Restart ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

cd /root/MT5-PropFirm-Bot

echo "--- Pulling latest code ---"
git pull origin $(git branch --show-current)
echo ""

echo "--- Installing dependencies ---"
pip3 install -r requirements.txt
echo ""

echo "--- Stopping existing bot ---"
systemctl stop futures-bot 2>/dev/null
pkill -f "futures_bot/bot.py" 2>/dev/null
sleep 2
echo "Bot stopped"
echo ""

echo "--- Starting bot ---"
if [ -f /etc/systemd/system/futures-bot.service ]; then
    systemctl start futures-bot
    sleep 3
    systemctl status futures-bot --no-pager | head -10
else
    echo "Service not installed, running install script..."
    bash scripts/install_bot.sh
fi
echo ""

echo "=== Fix & Restart Complete ==="
