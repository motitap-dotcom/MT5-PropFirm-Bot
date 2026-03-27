#!/bin/bash
# Trigger: v47 - check if MD fix works
echo "=== Status ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot
echo "--- Service ---"
systemctl is-active futures-bot
echo "--- Last 30 log ---"
tail -30 logs/bot.log
echo "=== Done ==="
