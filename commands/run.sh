#!/bin/bash
# Trigger: v56 - Deploy token fix and restart bot
cd /root/MT5-PropFirm-Bot

echo "=== DEPLOY TIMESTAMP ==="
date -u

echo ""
echo "=== PULLING LATEST CODE ==="
git fetch origin claude/build-cfd-trading-bot-fl0ld
git reset --hard origin/claude/build-cfd-trading-bot-fl0ld

echo ""
echo "=== STOPPING BOT ==="
systemctl stop futures-bot 2>/dev/null
sleep 2

echo ""
echo "=== INSTALLING DEPS ==="
pip3 install -r requirements.txt -q 2>&1 | tail -3

echo ""
echo "=== CLEARING OLD TOKEN FILE ==="
rm -f configs/.tradovate_token.json
echo "Old token file removed"

echo ""
echo "=== STARTING BOT ==="
systemctl start futures-bot
sleep 8

echo ""
echo "=== SERVICE STATUS ==="
systemctl is-active futures-bot
systemctl status futures-bot --no-pager -l 2>/dev/null | tail -10

echo ""
echo "=== RECENT LOGS ==="
journalctl -u futures-bot --no-pager -n 40 --since "30 sec ago"

echo ""
echo "=== BOT LOG ==="
tail -30 logs/bot.log 2>/dev/null || echo "No bot.log yet"
