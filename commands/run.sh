#!/bin/bash
# Trigger: v111 - Check if bot connected and trading (NO restart)
cd /root/MT5-PropFirm-Bot
echo "=== STATUS v111 ==="
date -u
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "=== Token file ==="
cat configs/.tradovate_token.json 2>/dev/null | head -1 | cut -c1-80 || echo "No token"
echo ""
echo "=== Bot Log (last 40) ==="
tail -40 logs/bot.log 2>/dev/null || echo "No log"
echo ""
echo "=== Journal (last 10) ==="
journalctl -u futures-bot --no-pager -n 10 2>&1
echo "=== END ==="
