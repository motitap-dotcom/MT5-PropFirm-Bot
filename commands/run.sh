#!/bin/bash
# Trigger: v115 - Full status with output file (NO restart)
cd /root/MT5-PropFirm-Bot
exec > commands/output.txt 2>&1

echo "=== STATUS v115 ==="
date -u
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo ""
mkdir -p status
echo "=== Bot Log (full) ==="
cat logs/bot.log 2>/dev/null || echo "No log"
echo ""
echo "=== Status JSON ==="
cat status/status.json 2>/dev/null || echo "No status"
echo ""
echo "=== Token ==="
cat configs/.tradovate_token.json 2>/dev/null | head -4
echo ""
echo "=== Journal (last 15) ==="
journalctl -u futures-bot --no-pager -n 15 2>&1
echo "=== END ==="
