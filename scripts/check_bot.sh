#!/bin/bash
echo "=== Full content of /root/tradovate-bot/server_cron.sh ==="
echo ""
if [ -f /root/tradovate-bot/server_cron.sh ]; then
  echo "Size: $(stat -c%s /root/tradovate-bot/server_cron.sh) bytes"
  echo ""
  cat /root/tradovate-bot/server_cron.sh
else
  echo "File not found"
fi
echo ""
echo "=== Full content of /root/MT5-PropFirm-Bot/server_cron.sh (for comparison) ==="
cat /root/MT5-PropFirm-Bot/server_cron.sh 2>/dev/null | head -30
echo ""

echo "=== Recent tradovate cron log (last 60 lines) ==="
tail -60 /var/log/tradovate-cron.log 2>/dev/null
echo ""

echo "=== Done ==="
