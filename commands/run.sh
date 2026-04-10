#!/bin/bash
# Trigger: v189
cd /root/MT5-PropFirm-Bot
echo "=== v189 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- Key activity ---"
grep -E "Got.*bars|New bar|dist=|SIGNAL|TRADE|order|placed|fill|Error|Trading cycle" logs/bot.log 2>/dev/null | grep "2026-04-10 1[4-9]:" | tail -30
