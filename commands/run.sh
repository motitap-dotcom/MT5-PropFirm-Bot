#!/bin/bash
# Trigger: v55 - Deploy token fix and restart bot
cd /root/MT5-PropFirm-Bot

echo "=== DEPLOY TIMESTAMP ==="
date -u

echo ""
echo "=== PULLING LATEST CODE ==="
git fetch origin claude/test-bot-trading-Z6n4I
git checkout claude/test-bot-trading-Z6n4I 2>/dev/null || git checkout -b claude/test-bot-trading-Z6n4I origin/claude/test-bot-trading-Z6n4I
git reset --hard origin/claude/test-bot-trading-Z6n4I

echo ""
echo "=== STOPPING BOT ==="
systemctl stop futures-bot 2>/dev/null
sleep 2

echo ""
echo "=== INSTALLING DEPS ==="
pip3 install -r requirements.txt -q 2>&1 | tail -3

echo ""
echo "=== STARTING BOT ==="
systemctl start futures-bot
sleep 5

echo ""
echo "=== SERVICE STATUS ==="
systemctl is-active futures-bot
systemctl status futures-bot --no-pager -l 2>/dev/null | tail -10

echo ""
echo "=== RECENT LOGS ==="
journalctl -u futures-bot --no-pager -n 30 --since "30 sec ago"

echo ""
echo "=== BOT LOG ==="
tail -20 logs/bot.log 2>/dev/null || echo "No bot.log yet"
