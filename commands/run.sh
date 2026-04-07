#!/bin/bash
# Trigger: v145 - Check after PYTHONPATH fix
cd /root/MT5-PropFirm-Bot
echo "=== v145 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
grep "PYTHONPATH" /etc/systemd/system/futures-bot.service 2>/dev/null || echo "NO PYTHONPATH IN SERVICE"
echo ""
journalctl -u futures-bot --no-pager -n 15 --since "3 min ago" 2>&1
echo ""
tail -10 logs/bot.log 2>/dev/null
