#!/bin/bash
# Trigger: v46 - check after deploy
echo "=== Status ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot
echo "--- Service ---"
systemctl is-active futures-bot
echo "--- MD fix? ---"
grep -c "md_base_url" futures_bot/core/tradovate_client.py && echo "YES" || echo "NO"
echo "--- Last 25 log ---"
tail -25 logs/bot.log
echo "=== Done ==="
