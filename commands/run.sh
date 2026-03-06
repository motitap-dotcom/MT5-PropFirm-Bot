#!/bin/bash
# =============================================================
# FIX: Enable AutoTrading in MT5 terminal config + restart
# =============================================================

echo "============================================"
echo "  FIX AutoTrading + Restart MT5"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
DATA_DIR="$MT5_DIR"

# 1. Stop MT5
echo "=== [1] Stopping MT5 ==="
pkill -f terminal64 2>/dev/null
sleep 3
pkill -9 -f terminal64 2>/dev/null
sleep 2
echo "MT5 stopped"
echo ""

# 2. Fix terminal.ini - enable AutoTrading
echo "=== [2] Fixing terminal.ini ==="
TERMINAL_INI="$DATA_DIR/terminal.ini"
if [ -f "$TERMINAL_INI" ]; then
    echo "Before fix:"
    grep -i "autotrading\|ExpertEnabled\|ExpertsEnable\|AutoTrade" "$TERMINAL_INI" 2>/dev/null || echo "(no matching lines)"

    # Remove old AutoTrading lines and add correct ones
    sed -i '/^AutoTrading=/d' "$TERMINAL_INI"
    sed -i '/^ExpertEnabled=/d' "$TERMINAL_INI"
    sed -i '/^ExpertsEnable=/d' "$TERMINAL_INI"

    # Add under [Experts] section if it exists, otherwise under [Common]
    if grep -q '\[Experts\]' "$TERMINAL_INI"; then
        sed -i '/\[Experts\]/a ExpertEnabled=1' "$TERMINAL_INI"
        sed -i '/\[Experts\]/a AutoTrading=1' "$TERMINAL_INI"
    elif grep -q '\[Common\]' "$TERMINAL_INI"; then
        sed -i '/\[Common\]/a AutoTrading=1' "$TERMINAL_INI"
    else
        echo -e "\n[Experts]\nExpertEnabled=1\nAutoTrading=1" >> "$TERMINAL_INI"
    fi

    echo "After fix:"
    grep -i "autotrading\|ExpertEnabled\|ExpertsEnable\|AutoTrade" "$TERMINAL_INI" 2>/dev/null
else
    echo "terminal.ini not found at $TERMINAL_INI"
fi
echo ""

# 3. Fix common.ini too
echo "=== [3] Fixing common.ini ==="
COMMON_INI="$DATA_DIR/config/common.ini"
if [ -f "$COMMON_INI" ]; then
    echo "Before fix:"
    grep -i "autotrading\|ExpertEnabled\|ExpertsEnable\|AutoTrade" "$COMMON_INI" 2>/dev/null || echo "(no matching lines)"

    sed -i '/^AutoTrading=/d' "$COMMON_INI"
    sed -i '/^ExpertEnabled=/d' "$COMMON_INI"

    if grep -q '\[Experts\]' "$COMMON_INI"; then
        sed -i '/\[Experts\]/a ExpertEnabled=1' "$COMMON_INI"
        sed -i '/\[Experts\]/a AutoTrading=1' "$COMMON_INI"
    elif grep -q '\[Common\]' "$COMMON_INI"; then
        sed -i '/\[Common\]/a AutoTrading=1' "$COMMON_INI"
    else
        echo -e "\n[Experts]\nExpertEnabled=1\nAutoTrading=1" >> "$COMMON_INI"
    fi

    echo "After fix:"
    grep -i "autotrading\|ExpertEnabled\|ExpertsEnable\|AutoTrade" "$COMMON_INI" 2>/dev/null
else
    echo "common.ini not found - creating it"
    mkdir -p "$DATA_DIR/config"
    echo -e "[Common]\nAutoTrading=1\n\n[Experts]\nExpertEnabled=1\nAutoTrading=1" > "$COMMON_INI"
    echo "Created with AutoTrading=1"
fi
echo ""

# 4. Also check/fix the chart profile to ensure EA has AutoTrading permission
echo "=== [4] Check EA chart config ==="
CHARTS_DIR="$DATA_DIR/profiles"
find "$CHARTS_DIR" -name "*.chr" 2>/dev/null | while read chr; do
    echo "Chart: $chr"
    grep -i "expert\|autotrading" "$chr" 2>/dev/null | head -5
    # Ensure ExpertAutoTrading=1 in chart files
    if grep -q "ExpertAutoTrading=" "$chr" 2>/dev/null; then
        sed -i 's/ExpertAutoTrading=0/ExpertAutoTrading=1/g' "$chr"
    fi
done
echo ""

# 5. Restart MT5 with autotrading
echo "=== [5] Starting MT5 with AutoTrading ==="
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# Make sure display is running
if ! pgrep Xvfb > /dev/null; then
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
fi

wine "$MT5_DIR/terminal64.exe" /portable /login:11797849 /server:FundedNext-Server /autotrading &
MT5_PID=$!
echo "MT5 started with PID: $MT5_PID"
sleep 15

# 6. Verify
echo ""
echo "=== [6] Verification ==="
if pgrep -f terminal64 > /dev/null; then
    echo "MT5 is RUNNING"
else
    echo "MT5 FAILED TO START!"
fi

# Wait for EA to load and check logs
sleep 10
echo ""
echo "=== [7] EA Log after restart ==="
LATEST_LOG=$(ls -t "$MT5_DIR/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "Log: $LATEST_LOG"
    tail -20 "$LATEST_LOG" 2>&1
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
