#!/bin/bash
# Trigger: v179
cd /root/MT5-PropFirm-Bot
echo "=== v179 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- Is new code running? (should see domcontentloaded, NOT networkidle) ---"
grep -E "domcontentloaded|networkidle|token valid for 2h|Browser auth" logs/bot.log 2>/dev/null | grep "2026-04-10 13:4" | tail -10
echo ""
echo "--- Last 30 log ---"
tail -30 logs/bot.log 2>/dev/null
