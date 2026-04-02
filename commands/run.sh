#!/bin/bash
# Trigger: v116 - Status to log + Telegram (NO restart)
cd /root/MT5-PropFirm-Bot
source .env 2>/dev/null
mkdir -p status

echo "=== STATUS v116 ==="
date -u
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "=== Bot Log (last 50) ==="
tail -50 logs/bot.log 2>/dev/null || echo "No log"
echo ""
echo "=== Status JSON ==="
cat status/status.json 2>/dev/null || echo "No status"
echo ""
echo "=== Token ==="
cat configs/.tradovate_token.json 2>/dev/null | head -4
echo ""
echo "=== Journal (last 10) ==="
journalctl -u futures-bot --no-pager -n 10 2>&1
echo "=== END ==="
