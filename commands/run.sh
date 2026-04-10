#!/bin/bash
# Trigger: v196
cd /root/MT5-PropFirm-Bot
echo "=== v196 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "Commit: $(git log -1 --oneline)"
echo ""
echo "Code check:"
echo "  fresh WS: $(grep -c 'ws = await websockets.connect' futures_bot/core/tradovate_client.py)"
echo "  RSI: $(grep 'rsi_over' futures_bot/strategies/vwap_mean_reversion.py | head -2)"
echo "  upVolume: $(grep -c 'upVolume' futures_bot/bot.py)"
echo ""
echo "--- SIGNALS + TRADES ---"
grep -i -E "SIGNAL.*entry|TRADE:|Market order|placed|fill|blocked" logs/bot.log 2>/dev/null | tail -10
echo ""
tail -20 logs/bot.log 2>/dev/null
