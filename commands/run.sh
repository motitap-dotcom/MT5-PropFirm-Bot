#!/bin/bash
# READ-ONLY status check v128
cd /root/MT5-PropFirm-Bot
echo "=== BOT STATUS ==="
date -u
echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "=== Bot Log (last 50) ==="
tail -50 logs/bot.log 2>/dev/null || echo "No log"
echo ""
echo "=== Journal ==="
journalctl -u futures-bot --no-pager -n 10 2>&1
echo "=== END ==="
