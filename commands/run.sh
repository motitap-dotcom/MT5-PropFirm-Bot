#!/bin/bash
# Trigger: v190
cd /root/MT5-PropFirm-Bot
echo "=== v190 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "--- Signals + Trades + Orders (today after 14:58) ---"
grep -E "SIGNAL|TRADE|order|placed|fill|execute|blocked|Position size" logs/bot.log 2>/dev/null | grep "2026-04-10 1[5-9]:" | tail -20
echo ""
echo "--- Live VWAP evals (latest cycle) ---"
grep -E "dist=|New bar|Got.*bars|Trading cycle" logs/bot.log 2>/dev/null | grep "2026-04-10 1[5-9]:" | tail -15
echo ""
echo "--- Errors ---"
grep "ERROR" logs/bot.log 2>/dev/null | grep "2026-04-10 1[5-9]:" | tail -5
