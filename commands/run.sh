#!/bin/bash
# Trigger: v108 - Restart bot with renewed token + check
cd /root/MT5-PropFirm-Bot
echo "=== v108 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"

# Bot should pick up the renewed token
# Just restart and check quickly (no sleep to avoid output issues)
systemctl restart futures-bot
echo "Restarted"
echo ""

# Give it a few seconds then check
sleep 8
echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "=== Last 15 journal ==="
journalctl -u futures-bot --no-pager -n 15 --since "10 sec ago" 2>&1
echo ""
echo "=== Last 10 bot.log ==="
tail -10 logs/bot.log 2>/dev/null
