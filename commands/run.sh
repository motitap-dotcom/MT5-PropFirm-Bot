#!/bin/bash
# =============================================================
# Fix #15: Use management server API + full fix_and_start script
# =============================================================

echo "=== FIX #15 - $(date) ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# ============================================
# STEP 1: Read the full fix_and_start.sh to understand how EA was attached
# ============================================
echo "--- STEP 1: Read fix_and_start.sh (full) ---"
cat /root/MT5-PropFirm-Bot/scripts/fix_and_start.sh 2>/dev/null
echo ""
echo "=========="
echo ""

# ============================================
# STEP 2: Read management server restart-mt5 logic
# ============================================
echo "--- STEP 2: Management server restart logic ---"
grep -A30 "restart-mt5\|restart_mt5\|def.*restart\|def.*start_mt5" /root/MT5-PropFirm-Bot/management/server.py 2>/dev/null | head -40
echo ""

# ============================================
# STEP 3: Check if there's a fix_compile_ea.sh
# ============================================
echo "--- STEP 3: fix_compile_ea.sh ---"
cat /root/MT5-PropFirm-Bot/scripts/fix_compile_ea.sh 2>/dev/null | head -80
echo ""

# ============================================
# STEP 4: Try the management API
# ============================================
echo "--- STEP 4: Management API ---"
# Find the management server port
MGMT_PORT=$(ss -tlnp | grep "server.py" | awk '{print $4}' | sed 's/.*://')
echo "Management server port: $MGMT_PORT"
if [ -n "$MGMT_PORT" ]; then
    echo "Calling /api/status..."
    curl -s "http://localhost:$MGMT_PORT/api/status" 2>/dev/null | head -20
    echo ""
fi
echo ""

# ============================================
# STEP 5: Check EA log status
# ============================================
echo "--- STEP 5: EA Status ---"
EA_LOG="${MT5_BASE}/MQL5/Logs/20260305.log"
if [ -f "$EA_LOG" ]; then
    echo "EA LOG EXISTS: $(stat -c%s "$EA_LOG") bytes"
    iconv -f UTF-16LE -t UTF-8 "$EA_LOG" 2>/dev/null | tail -10
else
    echo "No EA log for today"
fi
echo ""

echo "Terminal log (last 5):"
TERM_LOG=$(ls -t "${MT5_BASE}/logs/"*.log 2>/dev/null | head -1)
[ -f "$TERM_LOG" ] && iconv -f UTF-16LE -t UTF-8 "$TERM_LOG" 2>/dev/null | tail -5
echo ""

echo "=== DONE - $(date) ==="
