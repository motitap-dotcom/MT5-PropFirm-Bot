#!/bin/bash
# Trigger: v150 - verify bot is trading after status_writer fix
cd /root/MT5-PropFirm-Bot
echo "=== v150 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "Code: $(git log -1 --oneline)"
echo ""
echo "=== STATUS.JSON (should have live timestamp) ==="
cat status/status.json 2>/dev/null || echo "no status.json"
echo ""
echo "=== STATUS WRITER ERRORS (last 10) ==="
grep "Failed to write status" logs/bot.log 2>/dev/null | tail -10
echo ""
echo "=== AUTH EVENTS (last 10) ==="
grep -iE "authenticat|token|captcha|browser auth" logs/bot.log 2>/dev/null | tail -10
echo ""
echo "=== STRATEGY / SIGNALS (last 20) ==="
grep -iE "signal|vwap|orb|entry|exit|strategy|analys|setup|opportunity|candidate" logs/bot.log 2>/dev/null | tail -20
echo ""
echo "=== ORDERS & POSITIONS (last 15) ==="
grep -iE "order|filled|position|placed|trade" logs/bot.log 2>/dev/null | tail -15
echo ""
echo "=== ERRORS (last 15 non-status) ==="
grep -iE "error|exception|traceback" logs/bot.log 2>/dev/null | grep -v "Failed to write status" | tail -15
echo ""
echo "=== LAST 30 LOG LINES ==="
tail -30 logs/bot.log 2>/dev/null
