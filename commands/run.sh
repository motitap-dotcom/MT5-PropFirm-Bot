#!/bin/bash
# =============================================================
# DEBUG: Find AutoTrading config in MT5 files
# =============================================================

echo "============================================"
echo "  DEBUG: Find AutoTrading settings"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# ============ Find ALL ini files ============
echo "=== [1] ALL .ini files in MT5 folder ==="
find "$MT5" -name "*.ini" -type f 2>/dev/null
echo ""

# ============ Check each ini for auto/expert/trading ============
echo "=== [2] AutoTrading related settings in ALL ini files ==="
for f in $(find "$MT5" -name "*.ini" -type f 2>/dev/null); do
    matches=$(grep -i "auto\|expert\|trading\|algo" "$f" 2>/dev/null)
    if [ -n "$matches" ]; then
        echo "--- $f ---"
        echo "$matches"
        echo ""
    fi
done

# ============ Check common.ini specifically ============
echo "=== [3] Full content of key ini files ==="

for f in "$MT5/config/common.ini" "$MT5/community/accounts/current.ini" "$MT5/profiles/default.ini"; do
    if [ -f "$f" ]; then
        echo "--- $f ---"
        cat "$f"
        echo ""
    fi
done

# ============ Check the portable data folder ============
echo "=== [4] Check MQL5 folder for settings ==="
find "$MT5/MQL5" -name "*.ini" -o -name "*.cfg" -o -name "*.set" 2>/dev/null | head -20
echo ""

# ============ Wine registry ============
echo "=== [5] Wine registry for MT5 ==="
grep -r -i "autotrading\|metatrader\|terminal64" /root/.wine/*.reg 2>/dev/null | grep -i "auto\|expert\|trading" | head -20
echo ""

# ============ List profiles folder ============
echo "=== [6] Profiles and tester folders ==="
ls -la "$MT5/profiles/" 2>/dev/null
echo ""
ls -la "$MT5/tester/" 2>/dev/null
echo ""

# ============ Check startup.ini content ============
echo "=== [7] startup.ini full content ==="
cat "$MT5/config/startup.ini" 2>/dev/null
echo ""

echo "=== DEBUG DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
