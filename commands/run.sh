#!/bin/bash
# =============================================================
# Deep MT5 verification - Is EA truly running inside MT5?
# =============================================================

echo "============================================"
echo "  Deep MT5 & EA Verification"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# 1. MT5 process check
echo "=== [1] MT5 Process ==="
ps aux | grep -i "terminal64" | grep -v grep
echo ""

# 2. Check if EA .ex5 file exists (compiled)
echo "=== [2] EA Compiled File (.ex5) ==="
EA_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot"
ls -la "$EA_DIR/"*.ex5 2>/dev/null || echo "❌ No .ex5 files found!"
echo ""
echo "All EA files:"
ls -la "$EA_DIR/" 2>/dev/null
echo ""

# 3. Check MT5 terminal config - is EA attached to a chart?
echo "=== [3] MT5 Config - Charts & EAs ==="
MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
PROFILES_DIR="$MT5_DIR/config/profiles"
echo "--- Profiles directory ---"
ls -la "$PROFILES_DIR/" 2>/dev/null
echo ""
# Check default profile charts
for chart_file in "$PROFILES_DIR"/default/*.chr "$PROFILES_DIR"/*/*.chr; do
    if [ -f "$chart_file" ]; then
        echo "--- Chart: $(basename "$chart_file") ---"
        grep -i "expert\|ExpertName\|Symbol\|Period\|AutoTrading" "$chart_file" 2>/dev/null
        echo ""
    fi
done

# 4. Check terminal.ini for AutoTrading
echo "=== [4] Terminal Config (AutoTrading) ==="
TERMINAL_INI="$MT5_DIR/config/common.ini"
if [ -f "$TERMINAL_INI" ]; then
    cat "$TERMINAL_INI"
else
    echo "common.ini not found, checking other configs..."
    find "$MT5_DIR/config" -name "*.ini" -exec echo "--- {} ---" \; -exec cat {} \; 2>/dev/null
fi
echo ""

# 5. Check status.json timestamp - is it being updated?
echo "=== [5] status.json - Is it being updated live? ==="
STATUS_FILE="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot/status.json"
if [ -f "$STATUS_FILE" ]; then
    echo "File modified: $(stat -c '%y' "$STATUS_FILE")"
    cat "$STATUS_FILE"
    echo ""
    echo "--- Waiting 10 seconds to check if timestamp updates ---"
    BEFORE=$(stat -c '%Y' "$STATUS_FILE")
    sleep 10
    AFTER=$(stat -c '%Y' "$STATUS_FILE")
    if [ "$BEFORE" != "$AFTER" ]; then
        echo "✅ status.json IS being updated! EA is ALIVE."
        echo "New content:"
        cat "$STATUS_FILE"
    else
        echo "⚠️ status.json did NOT update in 10 seconds"
        echo "Checking MQL5 Experts log for heartbeat..."
    fi
else
    echo "❌ status.json not found!"
fi
echo ""

# 6. Check today's MQL5 log for heartbeat entries
echo "=== [6] Heartbeat Check (last entries from today's log) ==="
TODAY=$(date '+%Y%m%d')
MQL_LOG="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs/${TODAY}.log"
if [ -f "$MQL_LOG" ]; then
    echo "Log size: $(wc -c < "$MQL_LOG") bytes"
    echo "Log modified: $(stat -c '%y' "$MQL_LOG")"
    echo ""
    echo "--- Last 50 lines ---"
    tail -50 "$MQL_LOG"
else
    echo "Today's log not found at: $MQL_LOG"
    echo "Available logs:"
    ls -lt "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs/"*.log 2>/dev/null | head -5
fi
echo ""

# 7. Terminal logs
echo "=== [7] MT5 Terminal Log (connection status) ==="
TERM_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/Logs"
LATEST_TERM=$(ls -t "$TERM_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_TERM" ]; then
    echo "Log: $LATEST_TERM"
    echo "Modified: $(stat -c '%y' "$LATEST_TERM")"
    tail -30 "$LATEST_TERM"
fi
echo ""

# 8. Screenshot via xdotool (window title check)
echo "=== [8] MT5 Window Check ==="
export DISPLAY=:99
xdotool search --name "MetaTrader" getwindowname 2>/dev/null || echo "No MetaTrader window found (xdotool)"
wmctrl -l 2>/dev/null || echo "wmctrl not available"
echo ""

echo "=== VERIFICATION COMPLETE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
