#!/bin/bash
# Comprehensive EA diagnostics with dynamic dates
echo "=== EA DIAGNOSTICS $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
TODAY=$(date '+%Y%m%d')
EA_LOG="$MT5/MQL5/Logs/${TODAY}.log"

echo ""
echo "--- MT5 Process ---"
ps aux | grep terminal64 | grep -v grep || echo "MT5 NOT RUNNING!"

echo ""
echo "--- Account Connection ---"
# Find the most recent terminal log
TERM_LOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
if [ -n "$TERM_LOG" ]; then
    echo "Terminal log: $TERM_LOG ($(stat -c%s "$TERM_LOG") bytes)"
    # Show last auth-related lines
    cat "$TERM_LOG" | tr -d '\0' | grep -i "authoriz\|connect\|login\|error\|failed\|enabled\|synchronized" | tail -15
else
    echo "No terminal logs found"
fi

echo ""
echo "--- EA Log Today ($TODAY) ---"
if [ -f "$EA_LOG" ]; then
    echo "EA LOG EXISTS: $(stat -c%s "$EA_LOG") bytes"
    echo ""
    echo "=== LAST 80 LINES ==="
    cat "$EA_LOG" | tr -d '\0' | tail -80
    echo ""
    echo "=== SIGNAL SCAN RESULTS ==="
    cat "$EA_LOG" | tr -d '\0' | grep -i "SIGNAL\|NEWBAR\|BLOCKED\|TRADE\|HEARTBEAT\|SMC\|EMA\|FILTER\|RiskMgr\|Guardian\|NEWS\|ANALYZER\|ERROR\|FATAL\|WARNING" | tail -50
    echo ""
    echo "=== TRADE ATTEMPTS ==="
    cat "$EA_LOG" | tr -d '\0' | grep -i "BUY\|SELL\|OPEN\|CLOSE\|ticket\|TradeMgr" | tail -20
    echo ""
    echo "=== ERRORS ==="
    cat "$EA_LOG" | tr -d '\0' | grep -i "error\|fail\|blocked\|rejected\|invalid" | tail -20
else
    echo "NO EA LOG FOR TODAY!"
    echo "Available EA logs:"
    ls -lt "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -5
    # Try to read the most recent one
    RECENT_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
    if [ -n "$RECENT_LOG" ]; then
        echo ""
        echo "=== Most recent EA log: $RECENT_LOG ==="
        cat "$RECENT_LOG" | tr -d '\0' | tail -50
    fi
fi

echo ""
echo "--- Outbound Connections ---"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -10

echo ""
echo "--- EA File Check ---"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
if [ -d "$EA_DIR" ]; then
    echo "EA files:"
    ls -la "$EA_DIR/"*.ex5 2>/dev/null || echo "NO .ex5 compiled files!"
    echo ""
    echo "Source files:"
    ls -la "$EA_DIR/"*.mq5 "$EA_DIR/"*.mqh 2>/dev/null | wc -l
    echo "source files found"
else
    echo "EA directory NOT FOUND: $EA_DIR"
fi

echo ""
echo "--- AutoTrading Status ---"
# Check terminal log for autotrading status
if [ -n "$TERM_LOG" ]; then
    cat "$TERM_LOG" | tr -d '\0' | grep -i "automated trading" | tail -3
fi

echo ""
echo "--- VNC/Display Status ---"
ps aux | grep -E "Xvfb|x11vnc" | grep -v grep || echo "VNC not running"

echo ""
echo "--- Wine Version ---"
WINEPREFIX=/root/.wine wine --version 2>/dev/null

echo ""
echo "--- Disk Space ---"
df -h / | tail -1

echo ""
echo "--- Memory ---"
free -h | head -2

echo ""
echo "=== DIAGNOSTICS DONE ==="
