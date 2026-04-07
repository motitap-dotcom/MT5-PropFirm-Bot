#!/bin/bash
# Trigger: v130 - Read-only check
cd /root/MT5-PropFirm-Bot
echo "=== v130 ==="
echo "$(date -u '+%Y-%m-%d %H:%M UTC')"
echo "Service: $(systemctl is-active futures-bot)"
echo ""
tail -25 logs/bot.log 2>/dev/null
