#!/bin/bash
# Trigger: v192
cd /root/MT5-PropFirm-Bot
echo "=== v192 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "RSI thresholds: $(grep 'rsi_over' futures_bot/strategies/vwap_mean_reversion.py | head -2)"
echo ""
echo "--- TRADES / ORDERS / SIGNALS ---"
grep -i -E "TRADE:|Market order|placed|fill|SIGNAL.*entry|blocked|Position size" logs/bot.log 2>/dev/null | grep "2026-04-10 15:1" | tail -20
echo ""
echo "--- Last 15 ---"
tail -15 logs/bot.log 2>/dev/null
