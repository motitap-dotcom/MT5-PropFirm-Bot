#!/bin/bash
# Find MetaEditor and check EA compilation setup - 2026-03-16f
echo "=== FIND METAEDITOR $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

# 1. Search for metaeditor64.exe
echo "--- Searching for MetaEditor ---"
find /root/.wine -name "metaeditor64.exe" 2>/dev/null
find /root/.wine -name "metaeditor*.exe" 2>/dev/null

# 2. Check MT5 installation directory
echo ""
echo "--- MT5 directory contents ---"
ls -la "/root/.wine/drive_c/Program Files/MetaTrader 5/" 2>/dev/null | head -20

# 3. Check if there's a different MT5 path
echo ""
echo "--- Other possible MT5 locations ---"
find /root/.wine/drive_c -maxdepth 3 -name "terminal64.exe" 2>/dev/null
find /root/.wine/drive_c -maxdepth 3 -name "metaeditor*" 2>/dev/null

# 4. Check current running MT5 process path
echo ""
echo "--- Running MT5 process ---"
ps aux | grep -i terminal64 | grep -v grep

# 5. Check EA directory - current .ex5 and .mqh files
echo ""
echo "--- EA files on VPS ---"
MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
ls -la "$EA_DIR/" 2>/dev/null

# 6. Check if Guardian.mqh was updated (look for our fix markers)
echo ""
echo "--- Guardian.mqh fix check ---"
grep -n "POST-RESET\|prev_state\|prev_consec\|CAUTION.*HALT_TARGET" "$EA_DIR/Guardian.mqh" 2>/dev/null | head -10
if [ $? -eq 0 ]; then
    echo "FIX IS PRESENT in source files"
else
    echo "FIX NOT FOUND - source files not updated"
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
