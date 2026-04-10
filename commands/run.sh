#!/bin/bash
# Trigger: v194
cd /root/MT5-PropFirm-Bot
echo "=== v194 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
grep -i -E "SIGNAL.*entry|TRADE:|Market order|placed|fill|blocked|Got.*bars|New bar|dist=|Trading cycle" logs/bot.log 2>/dev/null | grep "2026-04-10 15:[2-5]" | tail -30
