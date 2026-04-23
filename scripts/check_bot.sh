#!/bin/bash
echo "=== Examine WORKING Tradovate-Bot - how does IT get market data? ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "--- our bot status ---"
echo "Active: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""

echo "--- Other bot source files ---"
ls /root/tradovate-bot/*.py 2>/dev/null | head -15
echo ""

echo "--- How does the OTHER bot fetch market data? (grep for chart/getChart/md) ---"
grep -rlE "getChart|md/subscribeQuote|market_data" /root/tradovate-bot/*.py 2>/dev/null | head -10
echo ""

echo "--- Show getChart usage in other bot ---"
grep -B2 -A20 "getChart" /root/tradovate-bot/*.py 2>/dev/null | head -80
echo ""

echo "--- Show how other bot sets up websocket ---"
grep -B2 -A20 "authorize\|md_ws\|md/subscribe" /root/tradovate-bot/*.py 2>/dev/null | head -60
echo ""

echo "--- Our bot log tail (did v166 fresh auth work?) ---"
PID=$(systemctl show futures-bot --property=MainPID --value)
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
tail -30 "$CWD/logs/bot.log" 2>/dev/null
echo ""

echo "=== Done ==="
