#!/bin/bash
# Trigger: v198 - trade analysis
cd /root/MT5-PropFirm-Bot
echo "=== v198 TRADE ANALYSIS $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- ALL trade-related activity ---"
grep -i -E "TRADE:|Market order|SIGNAL.*entry|blocked|Position size|SL|TP|Emergency|fill|position sync|cancel|flatten" logs/bot.log 2>/dev/null | grep "2026-04-10 15:5[5-9]\|2026-04-10 16:0" | head -40
echo ""
echo "--- Current positions ---"
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- Bot running now? ---"
grep -E "Trading cycle|New bar|dist=|SIGNAL|TRADE" logs/bot.log 2>/dev/null | grep "2026-04-10 16:0[5-9]\|2026-04-10 16:1" | tail -15
