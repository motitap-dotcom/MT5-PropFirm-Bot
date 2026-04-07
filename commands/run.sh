#!/bin/bash
# Trigger: v137 - Check if Playwright auth worked
cd /root/MT5-PropFirm-Bot
echo "=== v137 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo ""
tail -30 logs/bot.log 2>/dev/null
