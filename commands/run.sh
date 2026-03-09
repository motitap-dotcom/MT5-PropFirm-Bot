#!/bin/bash
# =============================================================
# Auto-attach EA to chart and restart MT5
# =============================================================

echo "============================================"
echo "  Auto-attach EA to EURUSD chart"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. Stop MT5 first
echo "=== [1] Stop MT5 ==="
pkill -f terminal64.exe 2>/dev/null
sleep 5
echo "MT5 stopped"
echo ""

# 2. Find chart profile files
echo "=== [2] Find chart profiles ==="
find "$MT5_DIR/Profiles" -name "*.chr" 2>/dev/null
echo ""
echo "Default profile:"
ls -la "$MT5_DIR/Profiles/default/" 2>/dev/null
echo ""
echo "All profiles:"
find "$MT5_DIR/Profiles" -type f 2>/dev/null
echo ""

# 3. Find any existing .chr files and show content
echo "=== [3] Chart file contents ==="
CHR_FILES=$(find "$MT5_DIR/Profiles" -name "*.chr" 2>/dev/null)
if [ -n "$CHR_FILES" ]; then
    for f in $CHR_FILES; do
        echo "--- $f ---"
        strings "$f" 2>/dev/null | head -40
        echo ""
    done
else
    echo "No .chr files found"
    echo ""
    echo "Looking for chart configs elsewhere:"
    find "$MT5_DIR" -name "*.chr" -o -name "chart*" -o -name "*.tpl" 2>/dev/null | head -20
fi
echo ""

# 4. Check terminal.ini for chart settings
echo "=== [4] terminal.ini ==="
if [ -f "$MT5_DIR/config/terminal.ini" ]; then
    strings "$MT5_DIR/config/terminal.ini" 2>/dev/null | head -50
else
    echo "No terminal.ini"
    find "$MT5_DIR/config" -type f 2>/dev/null
fi
echo ""

# 5. Check for saved chart templates
echo "=== [5] Templates ==="
find "$MT5_DIR" -name "*.tpl" 2>/dev/null | head -10
echo ""

# 6. Check tester/charts directories
echo "=== [6] Other chart locations ==="
ls -la "$MT5_DIR/Profiles/" 2>/dev/null
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
