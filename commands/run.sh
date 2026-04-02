#!/bin/bash
# Trigger: v114 - Check trades + full status (NO restart)
cd /root/MT5-PropFirm-Bot
echo "=== TRADE CHECK v114 ==="
date -u
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo ""
mkdir -p status
echo "=== Full bot log ==="
cat logs/bot.log 2>/dev/null || echo "No log"
echo ""
echo "=== Status JSON ==="
cat status/status.json 2>/dev/null || echo "No status"
echo ""
echo "=== Token ==="
cat configs/.tradovate_token.json 2>/dev/null | head -3
echo "=== END ==="
