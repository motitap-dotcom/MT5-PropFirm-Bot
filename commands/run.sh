#!/bin/bash
# Trigger: v173
cd /root/MT5-PropFirm-Bot
echo "=== PRE-MARKET v173 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "Commit: $(git log -1 --oneline)"
echo ""
echo "--- Code check ---"
echo "Volume fix: $(grep -c 'upVolume' futures_bot/bot.py)"
echo "VWAP dist: $(grep -c 'dist_sd' futures_bot/strategies/vwap_mean_reversion.py)"
echo "ORB disabled: $(grep -c 'Trend day detection disabled' futures_bot/bot.py)"
echo ""
echo "--- Last 30 log lines ---"
tail -30 logs/bot.log 2>/dev/null
echo ""
echo "--- Any VWAP values or signals? ---"
grep -E "dist=|SIGNAL|order|placed|fill" logs/bot.log 2>/dev/null | tail -10
