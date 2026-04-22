#!/bin/bash
# Trigger: v150 - find WHO is killing the bot
cd /root/MT5-PropFirm-Bot
echo "=== v150 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- Service summary ---"
systemctl status futures-bot --no-pager -n 0 | head -12
echo ""
echo "--- Journalctl: WHO stopped/started service (last 2h) ---"
journalctl -u futures-bot --no-pager --since "2 hours ago" | grep -iE "started|stopped|deactivated|activate|killed|main process" | tail -40
echo ""
echo "--- Cron log (last 60 lines) ---"
tail -60 /var/log/futures-bot-cron.log 2>/dev/null || echo "no cron log"
echo ""
echo "--- crontab for root ---"
crontab -l 2>/dev/null | grep -v '^#' | grep -v '^$'
echo ""
echo "--- Recent GitHub workflow activity (from .git ref updates) ---"
git reflog --date=iso | head -15
echo ""
echo "--- Restart history from server_cron ---"
tail -20 .restart_history 2>/dev/null | while read ts; do date -u -d "@$ts" '+%Y-%m-%d %H:%M:%S UTC'; done
echo ""
echo "--- Current running bot log (last 60 lines) ---"
tail -60 logs/bot.log 2>/dev/null
echo ""
echo "--- Processes referencing futures_bot ---"
ps -ef | grep -E "futures_bot|MT5-PropFirm" | grep -v grep
echo ""
echo "--- Who ran systemctl recently (audit) ---"
journalctl --no-pager --since "1 hour ago" _COMM=systemctl 2>/dev/null | tail -20 || echo "no systemctl audit"
echo ""
echo "--- Token file ---"
ls -la configs/.tradovate_token.json 2>/dev/null || echo "MISSING"
echo ""
echo "--- Time ---"
date -u
