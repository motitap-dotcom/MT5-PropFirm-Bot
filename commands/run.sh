#!/bin/bash
# Trigger: v140 - Debug: what branch/code is on VPS
cd /root/MT5-PropFirm-Bot
echo "=== v140 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Branch: $(git branch --show-current)"
echo "Commit: $(git log -1 --oneline)"
echo "Config: $([ -f configs/bot_config.json ] && echo EXISTS || echo MISSING)"
echo "Events: $([ -f configs/restricted_events.json ] && echo EXISTS || echo MISSING)"
echo "Token: $([ -f configs/.tradovate_token.json ] && echo EXISTS || echo MISSING)"
echo ".env: $([ -f .env ] && echo EXISTS || echo MISSING)"
echo ""
echo "=== systemctl status ==="
systemctl status futures-bot --no-pager 2>&1 | head -15
echo ""
echo "=== Reset limit check ==="
systemctl show futures-bot --property=NRestarts --value 2>/dev/null
echo ""
echo "=== Try manual restart ==="
systemctl reset-failed futures-bot 2>/dev/null
systemctl start futures-bot 2>/dev/null
sleep 3
echo "Service after restart: $(systemctl is-active futures-bot)"
