#!/bin/bash
# =============================================================
# Read chart files and inject EA, then restart MT5
# =============================================================

echo "============================================"
echo "  Inject EA into chart profile"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. Read the Default chart01.chr
echo "=== [1] Default chart01.chr ==="
cat "$MT5_DIR/Profiles/Charts/Default/chart01.chr" 2>/dev/null | strings | head -80
echo ""
echo "---END---"
echo ""

# 2. Read Euro chart01.chr (likely the EURUSD chart)
echo "=== [2] Euro chart01.chr ==="
cat "$MT5_DIR/Profiles/Charts/Euro/chart01.chr" 2>/dev/null | strings | head -80
echo ""
echo "---END---"
echo ""

# 3. Check which profile is active
echo "=== [3] Active profile ==="
grep -i "profile\|chart\|last" "$MT5_DIR/config/terminal.ini" 2>/dev/null
echo ""

# 4. Search for any .chr that mentions PropFirmBot
echo "=== [4] Charts with PropFirmBot ==="
grep -rl "PropFirmBot" "$MT5_DIR/Profiles/" 2>/dev/null
echo ""

# 5. Find the chart that has EURUSD
echo "=== [5] Charts with EURUSD ==="
grep -rl "EURUSD" "$MT5_DIR/Profiles/" 2>/dev/null
echo ""

# 6. Read that specific chart
echo "=== [6] EURUSD chart content ==="
for f in "$MT5_DIR/Profiles/Charts/Default/chart01.chr" "$MT5_DIR/Profiles/Charts/Euro/chart01.chr"; do
    if grep -q "EURUSD" "$f" 2>/dev/null; then
        echo "FOUND EURUSD in: $f"
        cat "$f" 2>/dev/null | strings
        echo ""
        break
    fi
done
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
