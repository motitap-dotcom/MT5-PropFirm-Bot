#!/bin/bash
# Verify all fixes are deployed and active
echo "=== VERIFICATION CHECK $(date '+%Y-%m-%d %H:%M:%S %Z') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"

# 1. Is MT5 running?
echo ""
echo "--- 1. MT5 Process ---"
if pgrep -f "terminal64.exe" > /dev/null 2>&1; then
    MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
    UPTIME=$(ps -o etime= -p "$MT5_PID" 2>/dev/null | tr -d ' ')
    echo "STATUS: RUNNING (PID=$MT5_PID, uptime=$UPTIME)"
else
    echo "STATUS: DOWN!"
fi

# 2. Check .ex5 timestamp vs .mq5 files
echo ""
echo "--- 2. Compiled EA (.ex5) vs Source (.mq5/.mqh) ---"
EX5="$EA_DIR/PropFirmBot.ex5"
if [ -f "$EX5" ]; then
    EX5_DATE=$(stat -c '%Y' "$EX5")
    EX5_HUMAN=$(stat -c '%y' "$EX5" | cut -d. -f1)
    echo ".ex5: $EX5_HUMAN ($(stat -c '%s' "$EX5") bytes)"

    # Check if any source file is newer than .ex5
    NEWER_COUNT=0
    for f in "$EA_DIR"/*.mq5 "$EA_DIR"/*.mqh; do
        [ -f "$f" ] || continue
        SRC_DATE=$(stat -c '%Y' "$f")
        if [ "$SRC_DATE" -gt "$EX5_DATE" ]; then
            echo "WARNING: $(basename $f) is NEWER than .ex5!"
            NEWER_COUNT=$((NEWER_COUNT + 1))
        fi
    done
    if [ "$NEWER_COUNT" -eq 0 ]; then
        echo "OK: .ex5 is up to date with all source files"
    fi
else
    echo "ERROR: .ex5 NOT FOUND!"
fi

# 3. Verify Guardian.mqh has the TimeGMT fix
echo ""
echo "--- 3. Guardian.mqh TimeGMT Fix ---"
if grep -q "broker_offset" "$EA_DIR/Guardian.mqh" 2>/dev/null; then
    echo "OK: Guardian.mqh has broker_offset fix (no TimeGMT)"
    grep "broker_offset\|gmt_h\|gmt_dow" "$EA_DIR/Guardian.mqh" | head -5
else
    echo "FAIL: Guardian.mqh still uses old TimeGMT()!"
fi

# 4. Verify StatusWriter.mqh has the TimeGMT fix
echo ""
echo "--- 4. StatusWriter.mqh TimeGMT Fix ---"
if grep -q "3\*3600" "$EA_DIR/StatusWriter.mqh" 2>/dev/null; then
    echo "OK: StatusWriter.mqh has GMT offset fix"
    grep "3\*3600" "$EA_DIR/StatusWriter.mqh"
else
    echo "FAIL: StatusWriter.mqh still uses old TimeGMT()!"
fi

# 5. Check watchdog cron
echo ""
echo "--- 5. Watchdog Cron ---"
CRON_LINE=$(crontab -l 2>/dev/null | grep "watchdog")
if [ -n "$CRON_LINE" ]; then
    echo "OK: $CRON_LINE"
else
    echo "FAIL: No watchdog in crontab!"
fi

# 6. Check watchdog script exists and is executable
echo ""
echo "--- 6. Watchdog Script ---"
WD="/root/MT5-PropFirm-Bot/scripts/mt5_watchdog.sh"
if [ -x "$WD" ]; then
    echo "OK: $WD exists and is executable"
else
    echo "FAIL: Watchdog script missing or not executable!"
fi

# 7. EA logs - check for errors and verify new code is running
echo ""
echo "--- 7. EA Log Analysis ---"
EA_LATEST=$(ls -t "$MT5_BASE/MQL5/Logs"/*.log 2>/dev/null | head -1)
if [ -n "$EA_LATEST" ]; then
    TMPLOG="/tmp/ea_verify.txt"
    iconv -f UTF-16LE -t UTF-8 "$EA_LATEST" 2>/dev/null > "$TMPLOG" || \
      sed 's/\x00//g' "$EA_LATEST" > "$TMPLOG"

    echo "Log file: $(basename $EA_LATEST)"
    echo "Log size: $(stat -c '%s' "$EA_LATEST") bytes"
    echo ""

    # Check for Guardian init with TRAILING (proves new code)
    echo "Guardian init (should show TRAILING):"
    grep "GUARDIAN.*INIT\|TRAILING" "$TMPLOG" 2>/dev/null | tail -3

    echo ""
    echo "Errors/Warnings:"
    grep -i "ERROR\|CRITICAL\|FATAL\|SHUTDOWN\|EMERGENCY" "$TMPLOG" 2>/dev/null | tail -10
    if [ $? -ne 0 ]; then
        echo "None found"
    fi

    echo ""
    echo "Last 15 lines of EA log:"
    tail -15 "$TMPLOG"
else
    echo "No EA logs found!"
fi

# 8. status.json freshness
echo ""
echo "--- 8. status.json ---"
STATUS_FILE="${MT5_BASE}/MQL5/Files/PropFirmBot/status.json"
if [ -f "$STATUS_FILE" ]; then
    AGE=$(( $(date +%s) - $(stat -c %Y "$STATUS_FILE") ))
    echo "Age: ${AGE}s"
    if [ "$AGE" -lt 60 ]; then
        echo "OK: Fresh (updated in last minute)"
    elif [ "$AGE" -lt 300 ]; then
        echo "WARN: Slightly stale (${AGE}s old)"
    else
        echo "FAIL: Very stale (${AGE}s old) - EA may not be running!"
    fi
    echo ""
    echo "Content:"
    cat "$STATUS_FILE" 2>/dev/null | python3 -m json.tool 2>/dev/null || cat "$STATUS_FILE"
else
    echo "FAIL: status.json not found!"
fi

# 9. Open positions check
echo ""
echo "--- 9. Terminal Logs (connection) ---"
TERM_LATEST=$(ls -t "$MT5_BASE/logs"/*.log 2>/dev/null | head -1)
if [ -n "$TERM_LATEST" ]; then
    echo "Terminal log: $(basename $TERM_LATEST)"
    TMPTERM="/tmp/term_verify.txt"
    iconv -f UTF-16LE -t UTF-8 "$TERM_LATEST" 2>/dev/null > "$TMPTERM" || \
      sed 's/\x00//g' "$TERM_LATEST" > "$TMPTERM"
    grep -i "connection\|authorized\|login\|error\|failed" "$TMPTERM" 2>/dev/null | tail -10
fi

echo ""
echo "=== VERIFICATION DONE $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
