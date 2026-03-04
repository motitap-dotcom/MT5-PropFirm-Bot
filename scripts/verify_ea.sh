#!/bin/bash
# Full EA diagnostics - uses dynamic date, strips null bytes for grep
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

    # Also copy configs
    cp configs/*.json "$MT5/MQL5/Files/PropFirmBot/" 2>/dev/null
    echo "Config files copied: $(ls -1 configs/*.json 2>/dev/null | wc -l) files"

    # Show version
    grep '#property version' EA/PropFirmBot.mq5 2>/dev/null || echo "Version unknown"
} || echo "Git repo not found"

echo ""
echo "--- EA Files on VPS ---"
ls -la "$MT5/MQL5/Experts/PropFirmBot/"*.ex5 2>/dev/null || echo "No compiled .ex5 found!"
ls -la "$MT5/MQL5/Experts/PropFirmBot/"*.mq5 2>/dev/null | head -3

echo ""
echo "--- Compile EA ---"
# Kill MT5 briefly to release file locks, compile, restart
MT5_PID=$(pgrep -f terminal64.exe | head -1)
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"

# Method 1: Try MetaEditor compile
DISPLAY=:99 WINEPREFIX=/root/.wine wine "$MT5/metaeditor64.exe" \
    /compile:"$EA_DIR/PropFirmBot.mq5" \
    /include:"$MT5/MQL5" /log 2>/dev/null &
COMPILE_PID=$!
sleep 10
kill $COMPILE_PID 2>/dev/null

# Check compile log
COMPILE_LOG="$EA_DIR/PropFirmBot.log"
if [ -f "$COMPILE_LOG" ]; then
    echo "Compile log:"
    cat "$COMPILE_LOG" | tr -d '\0' | tail -10
fi

echo "After compile:"
ls -la "$EA_DIR/"*.ex5 2>/dev/null || echo "No .ex5 found!"

# If .ex5 is still old, try restarting MT5 (it auto-compiles on load)
EX5_TIME=$(stat -c%Y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo 0)
MQ5_TIME=$(stat -c%Y "$EA_DIR/PropFirmBot.mq5" 2>/dev/null || echo 0)
if [ "$MQ5_TIME" -gt "$EX5_TIME" ]; then
    echo "WARNING: .mq5 is newer than .ex5 - restarting MT5 to force recompile..."
    # Stop MT5
    kill $MT5_PID 2>/dev/null
    sleep 3
    # Restart with same parameters
    DISPLAY=:99 WINEPREFIX=/root/.wine wine "$MT5/terminal64.exe" \
        /login:11797849 /password:gazDE62## /server:FundedNext-Server &
    sleep 15
    echo "MT5 restarted. New .ex5:"
    ls -la "$EA_DIR/"*.ex5 2>/dev/null
fi

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

    # Create clean version without null bytes for reliable grep
    CLEAN="/tmp/ea_log_clean.txt"
    tr -d '\0' < "$EALOG" > "$CLEAN"

    echo "--- Last 80 lines ---"
    tail -80 "$CLEAN"

    echo ""
    echo "--- Signal scan summary ---"
    echo "NEWBAR entries: $(grep -c '\[NEWBAR\]' "$CLEAN")"
    echo "SCAN entries: $(grep -c '\[SCAN\]' "$CLEAN")"
    echo "PREFLIGHT blocks: $(grep -c '\[PREFLIGHT\]' "$CLEAN")"
    echo "SMC signals: $(grep -c '\[SMC\]' "$CLEAN")"
    echo "EMA signals: $(grep -c '\[EMA\]' "$CLEAN")"
    echo "SIGNAL entries: $(grep -c '\[SIGNAL\]' "$CLEAN")"
    echo "TRADE entries: $(grep -c '\[TRADE\]' "$CLEAN")"
    echo "RiskMgr BLOCKED: $(grep -c '\[RiskMgr\] BLOCKED' "$CLEAN")"
    echo "NEWS blocks: $(grep -c '\[NEWS\]' "$CLEAN")"
    echo "GUARDIAN blocks: $(grep -c '\[GUARDIAN\]' "$CLEAN")"
    echo "HEARTBEAT entries: $(grep -c '\[HEARTBEAT\]' "$CLEAN")"

    echo ""
    echo "--- Last 3 HEARTBEATS ---"
    grep '\[HEARTBEAT\]' "$CLEAN" | tail -3

    echo ""
    echo "--- All signal activity (no RiskMgr BLOCKED) ---"
    grep -E '\[SCAN\]|\[SMC\]|\[EMA\]|\[SIGNAL\]|\[TRADE\]|\[PREFLIGHT\]|\[NEWS\].*blocked|\[GUARDIAN\]|\[ANALYZER\]' "$CLEAN" | tail -30

    echo ""
    echo "--- Time check (first and last entry) ---"
    head -1 "$CLEAN"
    tail -1 "$CLEAN"

    rm -f "$CLEAN"
else
    echo "No EA log for today ($TODAY)"
    echo "Latest EA logs:"
    ls -lt "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -5
    LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        echo ""
        echo "--- Latest EA log: $LATEST_LOG ---"
        cat "$LATEST_LOG" | tr -d '\0' | tail -50
    fi
fi

echo ""
echo "--- Account & Trading Status ---"
if [ -n "$TLOG" ]; then
    cat "$TLOG" | tr -d '\0' | grep -i 'automat\|trading.*enabled\|trading.*disabled\|authorized\|synchron' | tail -5
fi

echo ""
echo "--- MT5 Terminal Running State ---"
pgrep -la terminal64 2>/dev/null || echo "terminal64 NOT FOUND!"
pgrep -la metaeditor 2>/dev/null || echo "metaeditor not running (OK)"

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
