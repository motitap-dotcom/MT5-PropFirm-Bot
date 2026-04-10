#!/bin/bash
# Trigger: v188
cd /root/MT5-PropFirm-Bot
echo "=== v188 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Commit: $(git log -1 --oneline)"
echo "Has .closed fix: $(grep -c 'getattr.*closed' futures_bot/core/tradovate_client.py)"
echo ""
tail -30 logs/bot.log 2>/dev/null
