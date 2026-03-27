#!/bin/bash
# Trigger: v43 - check if bot is running with new token
echo "=== Status Check ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot
echo "--- Service ---"
systemctl is-active futures-bot 2>/dev/null || echo "not running"
echo "--- Last 25 log lines ---"
tail -25 logs/bot.log 2>/dev/null
echo "--- Fix deployed? ---"
grep -c "Proactive token renewal" futures_bot/core/tradovate_client.py && echo "YES" || echo "NO"
echo "=== Done ==="
