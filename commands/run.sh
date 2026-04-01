#!/bin/bash
# Trigger: v106 - Status check only (don't touch the bot)
cd /root/MT5-PropFirm-Bot
echo "=== STATUS CHECK v106 ==="
date -u
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "=== Token file ==="
cat configs/.tradovate_token.json 2>/dev/null || echo "No token"
echo ""
echo "=== Bot Log (last 30) ==="
tail -30 logs/bot.log 2>/dev/null || echo "No log"
echo ""
echo "=== Journal (last 10) ==="
journalctl -u futures-bot --no-pager -n 10 2>&1
echo "=== END ==="
