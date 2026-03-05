#!/bin/bash
# =============================================================
# FIX: Enable AutoTrading in common.ini + terminal.ini
# =============================================================

echo "============================================"
echo "  FIX: AutoTrading in common.ini"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# ============ STEP 0: Show terminal.ini ============
echo "=== [0] terminal.ini content ==="
cat "$MT5/config/terminal.ini" 2>/dev/null || echo "(not found)"
echo ""
echo "--- settings.ini content ---"
cat "$MT5/config/settings.ini" 2>/dev/null || echo "(not found)"
echo ""

# ============ STEP 1: Stop MT5 to modify configs safely ============
echo "=== [1] Stopping MT5 ==="
systemctl stop mt5.service
sleep 3
pkill -9 -f terminal64.exe 2>/dev/null
pkill -9 -f wineserver 2>/dev/null
sleep 2
echo "MT5 stopped."
echo ""

# ============ STEP 2: Fix common.ini - add AutoTrading to [Common] section ============
echo "=== [2] Fixing common.ini ==="
COMMON_INI="$MT5/config/common.ini"

# Add AutoTrading=1 to existing [Common] section
if grep -q '^AutoTrading=' "$COMMON_INI" 2>/dev/null; then
    sed -i 's/^AutoTrading=.*/AutoTrading=1/' "$COMMON_INI"
    echo "Updated existing AutoTrading setting"
else
    # Add after the [Common] section header
    sed -i '/^\[Common\]/a AutoTrading=1' "$COMMON_INI"
    echo "Added AutoTrading=1 to [Common] section"
fi

# Also make sure Experts section has proper settings
if ! grep -q '^ExpertsEnabled=' "$COMMON_INI" 2>/dev/null; then
    sed -i '/^\[Experts\]/a ExpertsEnabled=1' "$COMMON_INI"
fi

echo "--- Updated common.ini ---"
cat "$COMMON_INI"
echo ""

# ============ STEP 3: Fix terminal.ini if it exists ============
echo "=== [3] Fixing terminal.ini ==="
TERMINAL_INI="$MT5/config/terminal.ini"

if [ -f "$TERMINAL_INI" ]; then
    # Add or update AutoTrading
    if grep -q 'AutoTrading=' "$TERMINAL_INI"; then
        sed -i 's/AutoTrading=.*/AutoTrading=1/g' "$TERMINAL_INI"
    else
        # Add to the file
        echo "AutoTrading=1" >> "$TERMINAL_INI"
    fi

    if grep -q 'ExpertsEnabled=' "$TERMINAL_INI"; then
        sed -i 's/ExpertsEnabled=.*/ExpertsEnabled=1/g' "$TERMINAL_INI"
    else
        echo "ExpertsEnabled=1" >> "$TERMINAL_INI"
    fi

    echo "--- Updated terminal.ini ---"
    cat "$TERMINAL_INI"
else
    echo "terminal.ini not found, creating..."
    cat > "$TERMINAL_INI" << 'TINIEOF'
[Experts]
AutoTrading=1
ExpertsEnabled=1
AllowLiveTrading=1
TINIEOF
    cat "$TERMINAL_INI"
fi
echo ""

# Also check/fix the Capital-case Config folder (MT5 sometimes uses both)
COMMON_INI2="$MT5/Config/common.ini"
if [ -f "$COMMON_INI2" ] && [ "$COMMON_INI" != "$COMMON_INI2" ]; then
    echo "=== [3b] Also fixing Config/common.ini ==="
    if grep -q '^AutoTrading=' "$COMMON_INI2" 2>/dev/null; then
        sed -i 's/^AutoTrading=.*/AutoTrading=1/' "$COMMON_INI2"
    else
        sed -i '/^\[Common\]/a AutoTrading=1' "$COMMON_INI2"
    fi
    echo "Updated Config/common.ini too"
fi
echo ""

# ============ STEP 4: Start MT5 ============
echo "=== [4] Starting MT5 ==="
systemctl daemon-reload
systemctl start mt5.service
sleep 20

echo "--- mt5.service status ---"
systemctl is-active mt5.service
echo ""

echo "--- MT5 Process ---"
ps aux | grep terminal64 | grep -v grep
echo ""

# ============ STEP 5: Verify - check logs ============
echo "=== [5] VERIFICATION ==="
sleep 15

echo "--- Latest EA log (last 25 lines) ---"
LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    cat "$LATEST_LOG" 2>/dev/null | tr -d '\0' | tail -25
else
    echo "No EA logs yet"
fi
echo ""

echo "--- Latest Terminal log (last 10 lines) ---"
TERM_LOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
if [ -n "$TERM_LOG" ]; then
    cat "$TERM_LOG" 2>/dev/null | tr -d '\0' | tail -10
else
    echo "No terminal logs yet"
fi
echo ""

echo "=== FIX DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
