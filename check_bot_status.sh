#!/bin/bash
# PropFirmBot - Quick Status Check
# Usage from Windows PowerShell:
#   ssh root@77.237.234.2 'bash -s' < check_bot_status.sh
#
# Or copy to VPS and run:
#   bash /root/check_bot_status.sh

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_LOG_DIR="$MT5_DIR/MQL5/Logs"
TERM_LOG_DIR="$MT5_DIR/Logs"
FILES_DIR="$MT5_DIR/MQL5/Files/PropFirmBot"
TODAY=$(date -u +%Y%m%d)

echo ""
echo "=========================================="
echo "  PropFirmBot - Status Check"
echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "=========================================="
echo ""

# --- 1. Is MT5 running? ---
echo "[1] MT5 Process"
MT5_PID=$(pgrep -f "terminal64" 2>/dev/null | head -1)
if [ -n "$MT5_PID" ]; then
    echo "    STATUS: RUNNING (PID $MT5_PID)"
    CPU=$(ps -p "$MT5_PID" -o %cpu= 2>/dev/null | tr -d ' ')
    MEM=$(ps -p "$MT5_PID" -o %mem= 2>/dev/null | tr -d ' ')
    UPTIME=$(ps -p "$MT5_PID" -o etime= 2>/dev/null | tr -d ' ')
    echo "    CPU: ${CPU}% | RAM: ${MEM}% | Uptime: $UPTIME"
else
    echo "    STATUS: NOT RUNNING!"
    echo "    >>> MT5 is down - needs restart <<<"
fi
echo ""

# --- 2. VNC / Display ---
echo "[2] VNC & Display"
if pgrep -x "Xvfb" > /dev/null 2>&1; then
    echo "    Xvfb: RUNNING"
else
    echo "    Xvfb: NOT RUNNING"
fi
if pgrep -x "x11vnc" > /dev/null 2>&1; then
    echo "    VNC:  RUNNING (connect via RealVNC to 77.237.234.2:5900)"
else
    echo "    VNC:  NOT RUNNING"
fi
echo ""

# --- 3. Account Connection ---
echo "[3] Account Connection"
TERM_LOG=$(ls -t "$TERM_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$TERM_LOG" ]; then
    # Last auth event
    LAST_AUTH=$(grep -E "authorized on|authorization.*failed" "$TERM_LOG" 2>/dev/null | tail -1)
    if [ -n "$LAST_AUTH" ]; then
        if echo "$LAST_AUTH" | grep -q "authorized on"; then
            echo "    STATUS: CONNECTED"
            echo "    $LAST_AUTH"
        else
            echo "    STATUS: DISCONNECTED!"
            echo "    $LAST_AUTH"
        fi
    else
        echo "    No auth events in current log"
    fi

    # Trading mode
    TRADING=$(grep -E "trading has been enabled|trading is disabled" "$TERM_LOG" 2>/dev/null | tail -1)
    if [ -n "$TRADING" ]; then
        echo "    $TRADING"
    fi

    # Sync info
    SYNC=$(grep "terminal synchronized" "$TERM_LOG" 2>/dev/null | tail -1)
    if [ -n "$SYNC" ]; then
        echo "    $SYNC"
    fi
else
    echo "    No terminal log found"
fi
echo ""

# --- 4. EA Status ---
echo "[4] EA Status"
if [ -n "$TERM_LOG" ]; then
    EA_LOADED=$(grep "expert PropFirmBot.*loaded successfully" "$TERM_LOG" 2>/dev/null | tail -1)
    EA_REMOVED=$(grep "expert PropFirmBot.*removed" "$TERM_LOG" 2>/dev/null | tail -1)
    EA_ERROR=$(grep -E "expert PropFirmBot.*(failed|error)" "$TERM_LOG" 2>/dev/null | tail -1)

    if [ -n "$EA_LOADED" ]; then
        echo "    Last loaded: $EA_LOADED"
    fi
    if [ -n "$EA_ERROR" ]; then
        echo "    LAST ERROR: $EA_ERROR"
    fi

    # Check if loaded is newer than removed
    LOAD_TIME=$(echo "$EA_LOADED" | grep -oP '\d{2}:\d{2}:\d{2}' | tail -1)
    REMOVE_TIME=$(echo "$EA_REMOVED" | grep -oP '\d{2}:\d{2}:\d{2}' | tail -1)
    if [ -n "$LOAD_TIME" ] && [ -n "$REMOVE_TIME" ]; then
        if [[ "$LOAD_TIME" > "$REMOVE_TIME" ]]; then
            echo "    EA is ACTIVE (loaded after last remove)"
        else
            echo "    EA may be INACTIVE (removed after last load)"
        fi
    fi

    # AutoTrading
    AUTO=$(grep -E "automated trading is (enabled|disabled)" "$TERM_LOG" 2>/dev/null | tail -1)
    if [ -n "$AUTO" ]; then
        echo "    $AUTO"
    fi
fi
echo ""

# --- 5. EA Activity Log ---
echo "[5] EA Activity (Last 20 lines from EA log)"
EA_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$EA_LOG" ]; then
    EA_LOG_SIZE=$(stat -c%s "$EA_LOG" 2>/dev/null)
    EA_LOG_DATE=$(stat -c%y "$EA_LOG" 2>/dev/null | cut -d. -f1)
    echo "    Log: $(basename $EA_LOG) ($EA_LOG_SIZE bytes, modified: $EA_LOG_DATE)"
    echo "    --- Last 20 lines ---"
    tail -20 "$EA_LOG" 2>/dev/null | while IFS= read -r line; do
        echo "    $line"
    done
else
    echo "    No EA logs found"
fi
echo ""

# --- 6. Trade Activity ---
echo "[6] Trade Activity"
if [ -n "$EA_LOG" ]; then
    TRADE_ENTRIES=$(grep -ciE "TRADE|ORDER|OPEN|CLOSE|BUY|SELL|position" "$EA_LOG" 2>/dev/null)
    SIGNAL_ENTRIES=$(grep -ciE "SIGNAL|signal.*buy|signal.*sell" "$EA_LOG" 2>/dev/null)
    GUARDIAN_ENTRIES=$(grep -ciE "GUARDIAN|guardian|drawdown|halt" "$EA_LOG" 2>/dev/null)
    echo "    Trade-related log entries: $TRADE_ENTRIES"
    echo "    Signal-related entries: $SIGNAL_ENTRIES"
    echo "    Guardian-related entries: $GUARDIAN_ENTRIES"

    echo "    --- Recent trade signals ---"
    grep -iE "SIGNAL|TRADE|ORDER|BUY|SELL|OPEN|CLOSE|position opened|position closed" "$EA_LOG" 2>/dev/null | tail -10 | while IFS= read -r line; do
        echo "    $line"
    done
fi
echo ""

# --- 7. Status JSON (written by EA every 3 seconds) ---
echo "[7] EA Status JSON"
STATUS_FILE="$FILES_DIR/status.json"
if [ -f "$STATUS_FILE" ]; then
    STATUS_DATE=$(stat -c%y "$STATUS_FILE" 2>/dev/null | cut -d. -f1)
    echo "    Last updated: $STATUS_DATE"
    echo "    --- Content ---"
    cat "$STATUS_FILE" 2>/dev/null
    echo ""
else
    echo "    No status.json found (EA may not be writing status)"
fi
echo ""

# --- 8. Trade Journal ---
echo "[8] Trade Journal"
JOURNAL=$(find "$MT5_DIR/MQL5/Files/" -name "*journal*" -o -name "*trade*" 2>/dev/null | head -5)
if [ -n "$JOURNAL" ]; then
    echo "$JOURNAL" | while IFS= read -r f; do
        if [ -f "$f" ]; then
            LINES=$(wc -l < "$f" 2>/dev/null)
            echo "    $(basename $f): $LINES lines"
            echo "    --- Last 5 entries ---"
            tail -5 "$f" 2>/dev/null | while IFS= read -r line; do
                echo "    $line"
            done
        fi
    done
else
    echo "    No trade journal files found"
fi
echo ""

# --- 9. System Health ---
echo "[9] System Health"
echo "    Uptime: $(uptime -p 2>/dev/null || uptime)"
echo "    Load: $(cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}')"
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
USED_MEM=$(free -m | awk '/^Mem:/{print $3}')
echo "    Memory: ${USED_MEM}MB / ${TOTAL_MEM}MB"
echo "    Disk: $(df -h / | awk 'NR==2{printf "%s used, %s free", $5, $4}')"
echo ""

# --- 10. Summary ---
echo "=========================================="
echo "  SUMMARY"
echo "=========================================="

# Check each component
ISSUES=0

if [ -z "$MT5_PID" ]; then
    echo "  [X] MT5 is NOT running"
    ISSUES=$((ISSUES+1))
else
    echo "  [V] MT5 is running"
fi

if [ -n "$TERM_LOG" ] && grep -q "authorized on" "$TERM_LOG" 2>/dev/null; then
    LAST_FAIL=$(grep "authorization.*failed" "$TERM_LOG" 2>/dev/null | tail -1 | grep -oP '\d{2}:\d{2}:\d{2}' | tail -1)
    LAST_OK=$(grep "authorized on" "$TERM_LOG" 2>/dev/null | tail -1 | grep -oP '\d{2}:\d{2}:\d{2}' | tail -1)
    if [ -n "$LAST_FAIL" ] && [ -n "$LAST_OK" ] && [[ "$LAST_FAIL" > "$LAST_OK" ]]; then
        echo "  [X] Account DISCONNECTED (last auth failed)"
        ISSUES=$((ISSUES+1))
    else
        echo "  [V] Account connected"
    fi
else
    echo "  [?] Account connection unknown"
    ISSUES=$((ISSUES+1))
fi

if [ -f "$STATUS_FILE" ]; then
    # Check if status.json is recent (less than 5 minutes old)
    STATUS_AGE=$(( $(date +%s) - $(stat -c%Y "$STATUS_FILE" 2>/dev/null || echo 0) ))
    if [ "$STATUS_AGE" -lt 300 ]; then
        echo "  [V] EA is active (status updated ${STATUS_AGE}s ago)"
    else
        echo "  [X] EA may be stuck (status is ${STATUS_AGE}s old)"
        ISSUES=$((ISSUES+1))
    fi
else
    echo "  [?] No status.json - EA may not be active"
    ISSUES=$((ISSUES+1))
fi

if [ -n "$EA_LOG" ] && [ "$TRADE_ENTRIES" -gt 0 ] 2>/dev/null; then
    echo "  [V] Trade activity detected ($TRADE_ENTRIES entries)"
else
    echo "  [!] No trade activity found (bot may be waiting for signals)"
fi

echo ""
if [ "$ISSUES" -eq 0 ]; then
    echo "  >>> All systems OK <<<"
else
    echo "  >>> $ISSUES issue(s) found - see details above <<<"
fi
echo ""
echo "=========================================="
echo "  End of Status Check"
echo "=========================================="
