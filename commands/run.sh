#!/bin/bash
# Trigger: v183
cd /root/MT5-PropFirm-Bot
echo "=== v183 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- Auth status ---"
grep -E "token valid|domcontentloaded|Authenticated|Token renewed|Auth cooldown|Browser auth" logs/bot.log 2>/dev/null | grep "2026-04-10 14:" | tail -10
echo ""
echo "--- WebSocket status ---"
grep -E "WebSocket|Subscribing|chart|Received.*bars" logs/bot.log 2>/dev/null | grep "2026-04-10 14:" | tail -10
echo ""
echo "--- Trading + VWAP ---"
grep -E "dist=|SIGNAL|New bar|Trading cycle" logs/bot.log 2>/dev/null | grep "2026-04-10 14:" | tail -10
echo ""
echo "--- Errors ---"
grep "ERROR" logs/bot.log 2>/dev/null | grep "2026-04-10 14:" | tail -5
