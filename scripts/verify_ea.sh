#!/bin/bash
# PropFirmBot - Full Status Check (dynamic dates)
# Used by GitHub Actions workflow vps-check.yml
echo "=== PROPFIRMBOT STATUS $(date '+%Y-%m-%d %H:%M:%S %Z') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
TODAY=$(date '+%Y%m%d')

echo ""
echo "━━━ MT5 PROCESS ━━━"
if pgrep -f "terminal64" > /dev/null 2>&1; then
    echo "STATUS: RUNNING"
    ps aux | grep -i terminal64 | grep -v grep | awk '{printf "PID: %s | CPU: %s%% | MEM: %s%% | Since: %s %s\n", $2, $3, $4, $9, $10}'
else
    echo "STATUS: NOT_RUNNING"
fi

echo ""
echo "━━━ VNC ━━━"
pgrep -x "x11vnc" > /dev/null 2>&1 && echo "VNC: RUNNING" || echo "VNC: NOT_RUNNING"
pgrep -x "Xvfb" > /dev/null 2>&1 && echo "XVFB: RUNNING" || echo "XVFB: NOT_RUNNING"

echo ""
echo "━━━ NETWORK ━━━"
echo "Internet: $(ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1 && echo 'OK' || echo 'FAIL')"
echo "DNS: $(ping -c 1 -W 2 google.com > /dev/null 2>&1 && echo 'OK' || echo 'FAIL')"
echo "Outbound connections:"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -10

echo ""
echo "━━━ TERMINAL LOG ━━━"
TLOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
if [ -n "$TLOG" ]; then
    echo "File: $(basename $TLOG) | Size: $(stat -c%s "$TLOG") bytes | Modified: $(stat -c%y "$TLOG" | cut -d. -f1)"
    echo "--- Authorization ---"
    grep -i "authorized\|authorization.*failed\|Invalid account" "$TLOG" 2>/dev/null | tr -d '\0' | tail -5
    echo "--- Trading Status ---"
    grep -i "trading has been\|automated trading\|automat" "$TLOG" 2>/dev/null | tr -d '\0' | tail -5
    echo "--- Sync & Positions ---"
    grep -i "positions\|orders\|synchronized" "$TLOG" 2>/dev/null | tr -d '\0' | tail -5
    echo "--- Last 25 Lines ---"
    cat "$TLOG" | tr -d '\0' | tail -25
else
    echo "NO TERMINAL LOG FOUND"
fi

echo ""
echo "━━━ EA LOG ━━━"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$EALOG" ]; then
    echo "File: $(basename $EALOG) | Size: $(stat -c%s "$EALOG") bytes | Modified: $(stat -c%y "$EALOG" | cut -d. -f1)"
    TOTAL=$(wc -l < "$EALOG" 2>/dev/null)
    echo "Total lines: $TOTAL"
    echo "--- PropFirmBot entries ---"
    grep -i "PropFirmBot\|INIT\|GUARDIAN\|SIGNAL\|TRADE\|Guardian\|SignalEngine\|RiskManager\|Notify\|Analyzer" "$EALOG" 2>/dev/null | tr -d '\0' | tail -30
    echo "--- Last 30 Lines ---"
    cat "$EALOG" | tr -d '\0' | tail -30
else
    echo "NO EA LOG FOUND"
    echo "Available EA logs:"
    ls -lt "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -5
fi

echo ""
echo "━━━ EA FILES ━━━"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
if [ -d "$EA_DIR" ]; then
    echo "EX5:"
    ls -la "$EA_DIR/"*.ex5 2>/dev/null || echo "NO .ex5 FILES"
    SRC=$(ls "$EA_DIR/"*.mqh "$EA_DIR/"*.mq5 2>/dev/null | wc -l)
    echo "Source files: $SRC"
else
    echo "EA DIRECTORY NOT FOUND"
fi

echo ""
echo "━━━ TRADE JOURNAL ━━━"
JOURNAL=$(ls -t "$MT5/MQL5/Files/"*journal*.csv "$MT5/MQL5/Files/"*trade*.csv "$MT5/MQL5/Files/PropFirmBot/"*journal*.csv 2>/dev/null | head -1)
if [ -n "$JOURNAL" ]; then
    LINES=$(wc -l < "$JOURNAL" 2>/dev/null)
    echo "Journal: $(basename $JOURNAL) | Entries: $LINES"
    echo "--- Last 10 ---"
    tail -10 "$JOURNAL"
else
    echo "NO TRADE JOURNAL (bot has not traded yet)"
fi

echo ""
echo "━━━ SYSTEM ━━━"
echo "Uptime: $(uptime -p 2>/dev/null)"
echo "CPU Load: $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
USED_MEM=$(free -m | awk '/^Mem:/{print $3}')
echo "Memory: ${USED_MEM}MB / ${TOTAL_MEM}MB"
echo "Disk: $(df -h / | awk 'NR==2{printf "%s used, %s free", $5, $4}')"
echo "Wine: $(wine --version 2>/dev/null || echo 'NOT FOUND')"

echo ""
echo "━━━ SUMMARY ━━━"
# MT5
pgrep -f "terminal64" > /dev/null 2>&1 && echo "MT5_PROCESS=RUNNING" || echo "MT5_PROCESS=NOT_RUNNING"
# Server
if [ -n "$TLOG" ]; then
    LAST_A=$(grep -i "authorized\|authorization.*failed" "$TLOG" 2>/dev/null | tr -d '\0' | tail -1)
    echo "$LAST_A" | grep -qi "authorized on" && echo "SERVER=CONNECTED" || echo "SERVER=DISCONNECTED"
fi
# AutoTrading
if [ -n "$TLOG" ]; then
    LAST_T=$(grep -i "automated trading\|automat" "$TLOG" 2>/dev/null | tr -d '\0' | tail -1)
    echo "$LAST_T" | grep -qi "enabled" && echo "AUTOTRADING=ENABLED" || echo "AUTOTRADING=DISABLED"
fi
# EA
if [ -n "$EALOG" ]; then
    LAST_E=$(grep -i "PropFirmBot.*loaded\|PropFirmBot.*removed\|PropFirmBot.*failed" "$EALOG" 2>/dev/null | tr -d '\0' | tail -1)
    echo "$LAST_E" | grep -qi "loaded successfully" && echo "EA=LOADED" || echo "EA=NOT_LOADED"
fi
# Trades
if [ -n "$JOURNAL" ]; then
    echo "TRADES=YES ($(wc -l < "$JOURNAL") entries)"
else
    echo "TRADES=NO"
fi

echo ""
echo "=== DONE ==="
