#!/bin/bash
# Trigger: v99 - Quick status check
cd /root/MT5-PropFirm-Bot
echo "=== BOT STATUS ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "=== Token ==="
cat configs/.tradovate_token.json 2>/dev/null | head -5 || echo "No token"
echo ""
echo "=== Bot Log (last 30) ==="
tail -30 logs/bot.log 2>/dev/null || echo "No log"
echo ""
echo "=== Journal (last 15) ==="
journalctl -u futures-bot --no-pager -n 15 2>&1
echo ""
echo "=== END ==="
