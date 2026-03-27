#!/bin/bash
# Trigger: v51
echo "=== Status ==="
echo "T: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot
mkdir -p status logs
systemctl is-active futures-bot
grep -c "UnderlyingUnits" futures_bot/core/tradovate_client.py && echo "NEW" || echo "OLD"
tail -30 logs/bot.log
echo "=== Done ==="
