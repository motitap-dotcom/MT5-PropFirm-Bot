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

# Recent logs
echo "--- Bot Log (last 30 lines) ---"
tail -30 logs/bot.log 2>/dev/null || echo "No bot.log found"
echo ""

# Status JSON
echo "--- status.json ---"
cat status/status.json 2>/dev/null || echo "No status.json found"
echo ""

# Process info
echo "--- Bot Process ---"
ps aux | grep -E "[p]ython.*bot" || echo "No bot process found"
echo ""

# Disk and memory
echo "--- System Resources ---"
free -h | head -2
df -h / | tail -1
echo ""

# Journal logs
echo "--- Journal (last 15 lines) ---"
journalctl -u futures-bot --no-pager -n 15 2>&1
echo ""

echo "=== End of Status Check ==="
