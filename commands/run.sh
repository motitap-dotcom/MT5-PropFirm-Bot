#!/bin/bash
# Trigger: v168 - check what code is actually running
cd /root/MT5-PropFirm-Bot
echo "=== DEBUG v168 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Commit: $(git log -1 --oneline)"
echo "Branch: $(git branch --show-current)"
echo ""
echo "--- check_trend_day call in bot.py ---"
grep -n "check_trend_day\|ORB switch\|Trend day detection disabled" futures_bot/bot.py | head -5
echo ""
echo "--- VWAP on_bar trend check ---"
grep -n "trend_day_detected\|logger.info.*Price=\|ATR filter" futures_bot/strategies/vwap_mean_reversion.py | head -10
echo ""
echo "--- RSI thresholds ---"
grep -n "rsi_oversold\|rsi_overbought\|min_atr\|max_atr" futures_bot/strategies/vwap_mean_reversion.py | head -5
