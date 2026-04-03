#!/bin/bash
# Trigger: debug-trading-v1 - Full diagnostic: why bot not trading
cd /root/MT5-PropFirm-Bot

echo "=== BOT DEBUG - WHY NOT TRADING ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "=== 1. SERVICE STATUS ==="
systemctl status futures-bot --no-pager 2>&1 || echo "Service not found"
echo ""

echo "=== 2. IS PROCESS RUNNING? ==="
ps aux | grep -E "[p]ython.*bot" || echo "No bot process found"
echo ""

echo "=== 3. LAST 100 LOG LINES ==="
tail -100 /root/MT5-PropFirm-Bot/logs/bot.log 2>/dev/null || echo "No log file"
echo ""

echo "=== 4. STATUS JSON ==="
cat /root/MT5-PropFirm-Bot/status/status.json 2>/dev/null || echo "No status file"
echo ""

echo "=== 5. ENV FILE CHECK ==="
if [ -f /root/MT5-PropFirm-Bot/.env ]; then
    echo ".env exists"
    echo "TRADOVATE lines: $(grep -c 'TRADOVATE' /root/MT5-PropFirm-Bot/.env)"
    echo "TELEGRAM lines: $(grep -c 'TELEGRAM' /root/MT5-PropFirm-Bot/.env)"
else
    echo ".env NOT FOUND"
fi
echo ""

echo "=== 6. TOKEN FILE ==="
ls -la /root/MT5-PropFirm-Bot/configs/.tradovate_token.json 2>/dev/null || echo "No token file"
python3 -c "
import json
with open('/root/MT5-PropFirm-Bot/configs/.tradovate_token.json') as f:
    d = json.load(f)
print('Token expires:', d.get('expiration','unknown'))
" 2>/dev/null || echo "Cannot read token"
echo ""

echo "=== 7. CONFIG CHECK ==="
python3 -c "
import json
with open('/root/MT5-PropFirm-Bot/configs/bot_config.json') as f:
    c = json.load(f)
print('Trading enabled:', c.get('trading_enabled', 'NOT SET'))
print('Symbols:', c.get('symbols', 'NOT SET'))
print('Paper mode:', c.get('paper_mode', 'NOT SET'))
print('Max daily trades:', c.get('risk', {}).get('max_daily_trades', 'NOT SET'))
" 2>/dev/null || echo "Cannot read config"
echo ""

echo "=== 8. JOURNAL LOGS (last 50 lines) ==="
journalctl -u futures-bot --no-pager -n 50 2>&1
echo ""

echo "=== 9. DISK & MEMORY ==="
df -h / | tail -1
free -h | head -2
echo ""

echo "=== 10. CURRENT TIME vs TRADING SESSION ==="
echo "UTC now: $(date -u '+%H:%M')"
echo "ET now: $(TZ='America/New_York' date '+%H:%M %Z')"
echo "Trading session: 9:30-15:30 ET"
echo ""

echo "=== DONE ==="
