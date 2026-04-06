#!/bin/bash
# Trigger: v105 - Check if bot is running with token
cd /root/MT5-PropFirm-Bot
echo "=== Status v105 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "Service: $(systemctl is-active futures-bot)"
echo "Token: $([ -f configs/.tradovate_token.json ] && echo 'EXISTS' || echo 'MISSING')"
echo ""
echo "=== Service file ==="
grep "ExecStart\|PYTHONPATH\|Environment" /etc/systemd/system/futures-bot.service 2>/dev/null
echo ""
echo "=== Last 20 journal ==="
journalctl -u futures-bot --no-pager -n 20 2>&1
echo ""
echo "=== Last 15 bot.log ==="
tail -15 logs/bot.log 2>/dev/null || echo "No bot.log"
