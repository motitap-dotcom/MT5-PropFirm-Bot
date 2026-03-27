#!/bin/bash
# Trigger: v38 - quick status only
echo "=== Quick Status Check ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot

echo "--- Service ---"
systemctl is-active futures-bot 2>/dev/null || echo "not found"

echo "--- Process ---"
ps aux | grep -E '[p]ython.*bot' | head -5 || echo "none"

echo "--- Last 20 log lines ---"
tail -20 logs/bot.log 2>/dev/null || echo "no log"

echo "=== Done ==="
