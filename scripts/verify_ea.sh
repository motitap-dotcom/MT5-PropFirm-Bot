#!/bin/bash
# Full EA diagnostics - uses dynamic date
echo "=== EA DIAGNOSTICS $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
TODAY=$(date -u '+%Y%m%d')

echo "--- MT5 Process ---"
ps aux | grep terminal64 | grep -v grep || echo "MT5 NOT RUNNING!"

echo ""
echo "--- Outbound Connections ---"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -10

echo ""
echo "--- Deploy Latest Code from Git ---"
cd /root/MT5-PropFirm-Bot 2>/dev/null && {
    git fetch origin claude/fix-bot-server-connection-JbPec 2>&1 | tail -3
    git checkout claude/fix-bot-server-connection-JbPec 2>&1 | tail -1
    git pull origin claude/fix-bot-server-connection-JbPec 2>&1 | tail -3

    # Copy updated EA files
    cp EA/*.mq5 EA/*.mqh "$MT5/MQL5/Experts/PropFirmBot/" 2>/dev/null
    echo "EA files copied: $(ls -1 EA/*.mq5 EA/*.mqh 2>/dev/null | wc -l) files"

    # Show version
    grep '#property version' EA/PropFirmBot.mq5 2>/dev/null || echo "Version unknown"
} || echo "Git repo not found"

echo ""
echo "--- EA Files on VPS ---"
ls -la "$MT5/MQL5/Experts/PropFirmBot/"*.ex5 2>/dev/null || echo "No compiled .ex5 found!"
ls -la "$MT5/MQL5/Experts/PropFirmBot/"*.mq5 2>/dev/null | head -3

echo ""
echo "--- Compile EA ---"
WINEPREFIX=/root/.wine wine "$MT5/metaeditor64.exe" /compile:"$MT5/MQL5/Experts/PropFirmBot/PropFirmBot.mq5" /log 2>/dev/null
sleep 5
echo "After compile:"
ls -la "$MT5/MQL5/Experts/PropFirmBot/"*.ex5 2>/dev/null || echo "Compilation failed!"

echo ""
echo "--- Terminal Log (latest 30 lines) ---"
TLOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
if [ -n "$TLOG" ]; then
    echo "File: $TLOG ($(stat -c%s "$TLOG") bytes)"
    cat "$TLOG" | tr -d '\0' | tail -30
else
    echo "No terminal logs found"
fi

echo ""
echo "--- EA Log Today ($TODAY) ---"
EALOG="$MT5/MQL5/Logs/${TODAY}.log"
if [ -f "$EALOG" ]; then
    echo "EA LOG EXISTS! Size: $(stat -c%s "$EALOG") bytes"
    echo "--- Last 50 lines ---"
    cat "$EALOG" | tr -d '\0' | tail -50
    echo ""
    echo "--- Signal scan summary ---"
    echo "NEWBAR entries: $(grep -c '\[NEWBAR\]' "$EALOG" 2>/dev/null || echo 0)"
    echo "SMC signals: $(grep -c '\[SMC\]' "$EALOG" 2>/dev/null || echo 0)"
    echo "EMA signals: $(grep -c '\[EMA\]' "$EALOG" 2>/dev/null || echo 0)"
    echo "SIGNAL entries: $(grep -c '\[SIGNAL\]' "$EALOG" 2>/dev/null || echo 0)"
    echo "TRADE entries: $(grep -c '\[TRADE\]' "$EALOG" 2>/dev/null || echo 0)"
    echo "BLOCKED entries: $(grep -c -i 'block\|halt\|skip' "$EALOG" 2>/dev/null || echo 0)"
    echo "HEARTBEAT entries: $(grep -c '\[HEARTBEAT\]' "$EALOG" 2>/dev/null || echo 0)"
    echo ""
    echo "--- Last HEARTBEAT ---"
    grep '\[HEARTBEAT\]' "$EALOG" | tr -d '\0' | tail -1
    echo "--- Recent signals/blocks ---"
    grep -E '\[SMC\]|\[EMA\]|\[SIGNAL\]|\[TRADE\]|\[NEWBAR\].*Blocked|\[NEWS\]|BLOCKED|HALTED' "$EALOG" | tr -d '\0' | tail -20
else
    echo "No EA log for today ($TODAY)"
    echo "Latest EA logs:"
    ls -lt "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -5
    # Show most recent log
    LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        echo ""
        echo "--- Latest EA log: $LATEST_LOG ---"
        cat "$LATEST_LOG" | tr -d '\0' | tail -30
    fi
fi

echo ""
echo "--- Account & Trading Status ---"
# Check if autotrading is enabled from terminal log
if [ -n "$TLOG" ]; then
    grep -i 'automat\|trading.*enabled\|trading.*disabled' "$TLOG" | tr -d '\0' | tail -5
fi

echo ""
echo "--- Wine Version ---"
wine --version 2>/dev/null

echo ""
echo "--- Disk Space ---"
df -h / | tail -1

echo ""
echo "--- System Uptime ---"
uptime

echo ""
echo "=== DIAGNOSTICS DONE ==="
