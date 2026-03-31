#!/bin/bash
# Trigger: v87 - Full status check
cd /root/MT5-PropFirm-Bot

echo "=== BOT STATUS CHECK ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "=== Service Status ==="
systemctl is-active futures-bot
systemctl status futures-bot --no-pager -l 2>&1 | head -20
echo ""

echo "=== Recent Bot Log (last 40 lines) ==="
tail -40 logs/bot.log 2>/dev/null || echo "No bot.log found"
echo ""

echo "=== Status JSON ==="
cat status/status.json 2>/dev/null || echo "No status.json found"
echo ""

echo "=== Journal (last 30 lines) ==="
journalctl -u futures-bot --no-pager -n 30 2>&1
echo ""

echo "=== Disk & Memory ==="
df -h / | tail -1
free -h | head -2
echo ""

echo "=== Process Check ==="
ps aux | grep -i "[f]utures" || echo "No futures process found"
echo ""

echo "=== .env exists? ==="
ls -la .env 2>/dev/null || echo "No .env file"
echo ""

echo "=== END STATUS CHECK ==="
