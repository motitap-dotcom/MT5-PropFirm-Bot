#!/bin/bash
# Trigger: v39 - deploy fix + restart
echo "=== Deploy Fix & Restart ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot

# Pull latest code with the fix
echo "--- Updating code ---"
git fetch origin claude/build-cfd-trading-bot-fl0ld
git reset --hard origin/claude/build-cfd-trading-bot-fl0ld
echo "Code updated"

# Show the fix is there
echo "--- Verify fix ---"
grep -A3 "falling back to user/password" futures_bot/core/tradovate_client.py || echo "FIX NOT FOUND!"

# Restart bot
echo "--- Restarting ---"
systemctl stop futures-bot 2>/dev/null
sleep 2
systemctl start futures-bot
sleep 10

# Check
echo "--- Service ---"
systemctl is-active futures-bot

echo "--- Last 25 log lines ---"
tail -25 logs/bot.log 2>/dev/null

echo "=== Done ==="
