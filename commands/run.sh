#!/bin/bash
# Trigger: v153 - verify fix applied
cd /root/MT5-PropFirm-Bot
echo "=== Verify Fix v153 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- Critical Files ---"
echo "status dir: $(ls -d status/ 2>&1)"
echo "status.json: $(ls -la status/status.json 2>&1)"
echo "restricted_events: $(ls -la configs/restricted_events.json 2>&1)"
echo "bot_config: $(ls -la configs/bot_config.json 2>&1)"
echo ".env: $(ls -la .env 2>&1)"
echo "token: $(ls -la configs/.tradovate_token.json 2>&1)"
echo ""
echo "--- Last 25 Bot Log Lines ---"
tail -25 logs/bot.log 2>/dev/null
echo ""
echo "--- Live Status JSON ---"
cat status/status.json 2>/dev/null || echo "status.json not readable"
