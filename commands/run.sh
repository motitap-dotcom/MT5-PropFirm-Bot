#!/bin/bash
# Trigger: v127 - Check after org fix deploy
cd /root/MT5-PropFirm-Bot
echo "=== Status v127 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "=== Config org ==="
python3 -c "import json; print(json.load(open('configs/bot_config.json')).get('organization','?'))" 2>&1
echo ""
echo "=== Last 20 bot.log ==="
tail -20 logs/bot.log 2>/dev/null || echo "No bot.log"
