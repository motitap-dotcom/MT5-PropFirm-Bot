#!/bin/bash
# Check why bot is not trading
cd /root/MT5-PropFirm-Bot
echo "=== Full Trade Diagnosis $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- Service Status ---"
systemctl is-active futures-bot
systemctl show futures-bot --property=MainPID,ActiveState,SubState --value 2>/dev/null
echo ""
echo "--- Config ---"
cat configs/bot_config.json 2>/dev/null || echo "NO CONFIG FILE"
echo ""
echo "--- Status JSON ---"
cat status/status.json 2>/dev/null || echo "NO STATUS FILE"
echo ""
echo "--- Full Log (last 100 lines) ---"
tail -100 logs/bot.log 2>/dev/null || echo "NO LOG FILE"
echo ""
echo "--- Journal (last 30 lines) ---"
journalctl -u futures-bot --no-pager -n 30 2>/dev/null || echo "No journal"
