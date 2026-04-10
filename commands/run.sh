#!/bin/bash
# Trigger: v180
cd /root/MT5-PropFirm-Bot
echo "=== v180 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "--- Live bars + VWAP ---"
grep "2026-04-10.*New bar.*13:" logs/bot.log 2>/dev/null | tail -10
echo ""
echo "--- Live signals (not warmup) ---"
grep "2026-04-10.*SIGNAL" logs/bot.log 2>/dev/null | grep -v "13:47:37" | tail -10
echo ""
echo "--- Orders/Trades ---"
grep -i -E "order|placed|fill|execute_trade|Placing" logs/bot.log 2>/dev/null | grep "2026-04-10" | tail -10
echo ""
echo "--- Last 20 log ---"
tail -20 logs/bot.log 2>/dev/null
