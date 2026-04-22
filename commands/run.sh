#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== $(date -u '+%Y-%m-%d %H:%M UTC')  NY=$(TZ=America/New_York date '+%H:%M')  Wk=$(date -u '+%A') ==="
echo "Service: $(systemctl is-active futures-bot)  PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- last 60 bot log lines since restart ---"
awk '/2026-04-22 14:39:35/,0' logs/bot.log | tail -80
echo ""
echo "--- any TRADE attempts? ---"
grep -E "TRADE:|SIGNAL|blocked by|Position size|Trade blocked" logs/bot.log | tail -20
echo ""
echo "--- current bar & indicator snapshots ---"
grep "strategy.vwap" logs/bot.log | tail -15
echo ""
echo "--- status.json ---"
cat status/status.json 2>/dev/null
