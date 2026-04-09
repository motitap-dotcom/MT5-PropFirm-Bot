#!/bin/bash
# Trigger: v167
cd /root/MT5-PropFirm-Bot
echo "=== v167 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo ""
tail -40 logs/bot.log 2>/dev/null
