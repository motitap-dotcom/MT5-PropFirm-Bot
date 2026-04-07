#!/bin/bash
# Trigger: v133 - Just read current bot.log
cd /root/MT5-PropFirm-Bot
echo "=== v133 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "Token: $([ -f configs/.tradovate_token.json ] && echo EXISTS || echo MISSING)"
echo ""
tail -30 logs/bot.log 2>/dev/null
