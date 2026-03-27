#!/bin/bash
# Trigger: v40 - quick check after deploy
echo "=== Quick Status ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot
echo "--- Service ---"
systemctl is-active futures-bot 2>/dev/null || echo "not running"
echo "--- Fix verify ---"
grep -c "falling back to user/password" futures_bot/core/tradovate_client.py 2>/dev/null && echo "FIX IS DEPLOYED" || echo "FIX NOT YET DEPLOYED"
echo "--- Last 25 log lines ---"
tail -25 logs/bot.log 2>/dev/null
echo "=== Done ==="
