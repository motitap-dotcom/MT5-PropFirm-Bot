#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== Status $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "--- Status JSON ---"
cat status/status.json 2>/dev/null || echo "No status.json"
echo ""
echo "--- Last 40 log lines ---"
tail -40 logs/bot.log 2>/dev/null
