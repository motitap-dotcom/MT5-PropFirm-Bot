#!/bin/bash
# Trigger: v129 - Check if bot connected
cd /root/MT5-PropFirm-Bot

# Quick restart to pick up new token
systemctl restart futures-bot 2>/dev/null
sleep 12

echo "=== Status v129 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "=== Last 25 bot.log ==="
tail -25 logs/bot.log 2>/dev/null
