#!/bin/bash
# Trigger: v49
echo "=== Status ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot
mkdir -p status logs
echo "--- Service ---"
systemctl is-active futures-bot
echo "--- Last 30 log ---"
tail -30 logs/bot.log
echo "=== Done ==="
