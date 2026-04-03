#!/bin/bash
# Trigger: v125 - STATUS ONLY (no restart, no git reset, safe)
cd /root/MT5-PropFirm-Bot
echo "Service: $(systemctl is-active futures-bot)"
echo "---"
tail -30 logs/bot.log 2>/dev/null || echo "No log"
echo "---"
journalctl -u futures-bot --no-pager -n 5 2>&1
