#!/bin/bash
# Trigger: v141
cd /root/MT5-PropFirm-Bot
echo "=== v141 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Branch: $(git branch --show-current)"
echo "Commit: $(git log -1 --oneline)"
echo "Config: $([ -f configs/bot_config.json ] && echo YES || echo NO)"
echo "Service: $(systemctl is-active futures-bot)"
echo "Restarts: $(systemctl show futures-bot --property=NRestarts --value 2>/dev/null)"
echo ""
systemctl status futures-bot --no-pager 2>&1 | head -10
echo ""
tail -10 logs/bot.log 2>/dev/null
