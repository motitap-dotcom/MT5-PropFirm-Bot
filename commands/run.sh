#!/bin/bash
# Trigger: v87 - Status check only (no restart)
cd /root/MT5-PropFirm-Bot

echo "=== Bot Status Check - $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
echo ""

# Service status
echo "--- Service Status ---"
systemctl is-active futures-bot
systemctl status futures-bot --no-pager -l 2>&1 | head -20
echo ""

# Uptime
echo "--- Bot Uptime ---"
ps aux | grep -E '[p]ython.*bot' || echo "No bot process found"
echo ""

# Recent logs
echo "--- Last 30 lines of bot.log ---"
tail -30 logs/bot.log 2>/dev/null || echo "No bot.log found"
echo ""

# Status JSON
echo "--- status.json ---"
cat status/status.json 2>/dev/null || echo "No status.json found"
echo ""

# Check .env exists
echo "--- Environment ---"
if [ -f .env ]; then echo ".env exists"; else echo ".env MISSING"; fi
if [ -f configs/.tradovate_token.json ]; then echo "Token file exists"; else echo "No token file"; fi
echo ""

# Disk and memory
echo "--- System Resources ---"
df -h / | tail -1
free -h | head -2
echo ""

echo "=== End Status Check ==="
