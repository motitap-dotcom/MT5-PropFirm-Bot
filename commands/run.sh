#!/bin/bash
# Trigger: status-check-2026-04-14
cd /root/MT5-PropFirm-Bot
echo "=== Status $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "Code: $(git log -1 --oneline)"
echo ""
echo "--- status.json ---"
cat status/status.json 2>/dev/null || echo "no status.json"
echo ""
echo "--- last 30 log lines ---"
tail -30 logs/bot.log 2>/dev/null || echo "no bot.log"
