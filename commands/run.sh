#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== Quick Status $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "Enabled: $(systemctl is-enabled futures-bot 2>/dev/null)"
echo "Code: $(git log -1 --oneline)"
echo "start_bot.sh: $(ls -la scripts/start_bot.sh 2>/dev/null || echo 'MISSING')"
echo ""
echo "--- Journal last 6 ---"
journalctl -u futures-bot --no-pager -n 6
