#!/bin/bash
# Trigger: v143
cd /root/MT5-PropFirm-Bot
echo "=== v143 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo ""
journalctl -u futures-bot --no-pager -n 15 --since "5 min ago" 2>&1
echo ""
tail -15 logs/bot.log 2>/dev/null
