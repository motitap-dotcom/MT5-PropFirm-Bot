#!/bin/bash
# Trigger: v134 - Check after Playwright deploy
cd /root/MT5-PropFirm-Bot
echo "=== v134 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "Token: $([ -f configs/.tradovate_token.json ] && echo EXISTS || echo MISSING)"
echo "Playwright: $(python3 -c 'import playwright; print("OK")' 2>&1)"
echo ""
tail -30 logs/bot.log 2>/dev/null
