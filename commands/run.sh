#!/bin/bash
# Trigger: v149 - check if bot is trading
cd /root/MT5-PropFirm-Bot
echo "=== v149 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "Code: $(git log -1 --oneline)"
echo ""
echo "=== STATUS.JSON ==="
cat status/status.json 2>/dev/null || echo "no status.json"
echo ""
echo "=== OPEN POSITIONS (tradovate) ==="
grep -iE "position|filled|order|trade" logs/bot.log 2>/dev/null | tail -20
echo ""
echo "=== LAST 40 LOG LINES ==="
tail -40 logs/bot.log 2>/dev/null
