#!/bin/bash
echo "=== Bot Status After Deploy ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "--- Service ---"
systemctl is-active futures-bot
echo ""

echo "--- Token File ---"
cat /root/MT5-PropFirm-Bot/configs/.tradovate_token.json 2>/dev/null || echo "No token"
echo ""

echo "--- Bot Log (last 40 lines) ---"
tail -40 /root/MT5-PropFirm-Bot/logs/bot.log 2>/dev/null || echo "No log"
echo ""

echo "--- Journal (last 20) ---"
journalctl -u futures-bot --no-pager -n 20 2>&1
echo ""

echo "--- Branch ---"
cd /root/MT5-PropFirm-Bot && git log --oneline -3
echo ""
echo "=== END ==="
