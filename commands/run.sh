#!/bin/bash
# Trigger: v101 - Just check status after deploy fixed things
cd /root/MT5-PropFirm-Bot
echo "=== Status v101 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "=== Service file ExecStart ==="
grep "ExecStart\|PYTHONPATH\|Environment" /etc/systemd/system/futures-bot.service 2>/dev/null
echo ""
echo "=== .env ==="
[ -f .env ] && echo "exists ($(wc -l < .env) lines)" || echo "MISSING"
echo ""
echo "=== Last 15 journal ==="
journalctl -u futures-bot --no-pager -n 15 2>&1
echo ""
echo "=== Last 10 bot.log ==="
tail -10 logs/bot.log 2>/dev/null || echo "No bot.log"
