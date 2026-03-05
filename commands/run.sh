#!/bin/bash
# =============================================================
# Fix #17: Create chart profile with EA + restart MT5
# The Default chart profile directory is EMPTY - that's why EA isn't loading
# =============================================================

echo "=== FIX #17 - $(date) ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine
export WINEDEBUG=-all

# ============================================
# STEP 1: Read an existing chart profile to understand format
# ============================================
echo "--- STEP 1: Read existing chart profile ---"
SAMPLE_CHR="${MT5_BASE}/MQL5/Profiles/Charts/Euro/chart01.chr"
echo "Sample chart file: $SAMPLE_CHR"
echo "File info:"
file "$SAMPLE_CHR" 2>/dev/null
echo ""
echo "Hex first bytes:"
xxd "$SAMPLE_CHR" 2>/dev/null | head -5
echo ""
echo "Content (trying different encodings):"
echo "--- UTF-16LE ---"
iconv -f UTF-16LE -t UTF-8 "$SAMPLE_CHR" 2>/dev/null | head -60
echo "--- ASCII ---"
cat "$SAMPLE_CHR" 2>/dev/null | strings | head -60
echo ""

# Also check common.ini properly
echo "--- common.ini (hex dump of StartUp section) ---"
# Find the StartUp section by searching in hex
strings "${MT5_BASE}/config/common.ini" 2>/dev/null | head -80
echo ""

# Read common.ini raw
echo "--- common.ini raw bytes ---"
xxd "${MT5_BASE}/config/common.ini" 2>/dev/null | head -60
echo ""

# ============================================
# STEP 2: Check what active profile MT5 is using
# ============================================
echo "--- STEP 2: Active profile directories ---"
ls -la "${MT5_BASE}/MQL5/Profiles/Charts/" 2>/dev/null
echo ""

echo "Default dir contents:"
ls -la "${MT5_BASE}/MQL5/Profiles/Charts/Default/" 2>/dev/null
echo ""

# Check if MT5 has a lastprofile or similar setting
echo "Profile info from terminal config:"
strings "${MT5_BASE}/config/common.ini" 2>/dev/null | grep -i "chart\|profile\|default\|last" || echo "(nothing found)"
echo ""

echo "=== DONE - $(date) ==="
