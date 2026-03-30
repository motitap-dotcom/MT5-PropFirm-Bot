#!/bin/bash
echo "=== TradeDay Bot - Full Diagnostic v88 ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "--- System ---"
uptime
free -h | head -3
echo ""

echo "--- MT5 Process ---"
ps aux | grep -i "terminal64\|metatrader" | grep -v grep || echo "MT5 not running"
echo ""

echo "--- Search for .ex5 files ---"
find /root -name "*.ex5" -type f 2>/dev/null || echo "No .ex5 files found"
echo ""

echo "--- Search for PropFirmBot files ---"
find /root -name "*PropFirmBot*" -type f 2>/dev/null || echo "No PropFirmBot files found"
echo ""

echo "--- MT5 Experts Directory ---"
ls -laR "$MT5_DIR/MQL5/Experts/" 2>/dev/null || echo "Experts dir not found"
echo ""

echo "--- MT5 Terminal Log (last 30 lines) ---"
LATEST_LOG=$(ls -t "$MT5_DIR/logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "File: $LATEST_LOG"
    tail -30 "$LATEST_LOG"
else
    echo "No MT5 terminal logs found"
fi
echo ""

echo "--- EA Log (latest, last 30 lines) ---"
LATEST_EA_LOG=$(ls -t "$MT5_DIR/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_EA_LOG" ]; then
    echo "File: $LATEST_EA_LOG"
    tail -30 "$LATEST_EA_LOG"
else
    echo "No EA logs found"
fi
echo ""

echo "--- Python Bot Service ---"
systemctl status futures-bot --no-pager 2>&1 | head -5 || echo "futures-bot service not found"
echo ""

echo "--- Python Bot Log ---"
tail -20 /root/MT5-PropFirm-Bot/logs/bot.log 2>/dev/null || echo "No Python bot log"
echo ""

echo "--- status.json ---"
cat "$MT5_DIR/MQL5/Files/status.json" 2>/dev/null || cat /root/MT5-PropFirm-Bot/status/status.json 2>/dev/null || echo "No status.json"
echo ""

echo "--- Network ---"
curl -s -o /dev/null -w "Tradovate Demo API: HTTP %{http_code}\n" https://demo.tradovateapi.com/v1 2>/dev/null
curl -s -o /dev/null -w "Telegram API: HTTP %{http_code}\n" https://api.telegram.org 2>/dev/null
echo ""

echo "--- Repo State ---"
cd /root/MT5-PropFirm-Bot
echo "Branch: $(git branch --show-current)"
echo "Last commit: $(git log --oneline -1)"
echo ""

echo "=== Check Complete ==="
