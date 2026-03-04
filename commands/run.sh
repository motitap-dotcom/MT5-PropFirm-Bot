#!/bin/bash
# =============================================================
# Check compilation results
# =============================================================

echo "=== Check Compile Results - $(date) ==="
echo ""

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"

# Check compile log
echo "--- Compile Log ---"
if [ -f "$MT5_DIR/compile.log" ]; then
    cat "$MT5_DIR/compile.log"
else
    echo "No compile.log found in MT5 dir"
fi
echo ""

# Check MetaEditor logs
echo "--- MetaEditor Logs (recent) ---"
LOGS_DIR="$MT5_DIR/MQL5/Logs"
if [ -d "$LOGS_DIR" ]; then
    LATEST_LOG=$(ls -t "$LOGS_DIR"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        echo "Latest log: $LATEST_LOG"
        tail -30 "$LATEST_LOG"
    else
        echo "No log files found"
    fi
else
    echo "Logs dir not found"
fi
echo ""

# Check .ex5 file
echo "--- EA File Status ---"
echo "Source (.mq5): $(stat -c '%y %s bytes' "$EA_DIR/PropFirmBot.mq5" 2>/dev/null || echo 'NOT FOUND')"
echo "Compiled (.ex5): $(stat -c '%y %s bytes' "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo 'NOT FOUND')"
echo ""

# Check MT5 status
echo "--- MT5 Status ---"
pgrep -a terminal64 && echo "MT5 is RUNNING" || echo "MT5 is NOT running"
echo ""

echo "=== Done ==="
