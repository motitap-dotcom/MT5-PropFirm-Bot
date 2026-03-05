#!/bin/bash
# Find and fix the XAUUSD param in MT5 chart settings
echo "=== FIND XAUUSD SETTING $(date) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# Search ALL .chr files for PropFirmBot
echo "=== ALL CHART FILES WITH PROPFIRMBOT ==="
find "$MT5" -name "*.chr" 2>/dev/null | while read f; do
    if grep -q "PropFirmBot" "$f" 2>/dev/null; then
        echo ""
        echo "=== FOUND: $f ==="
        # Show params related to symbols/XAUUSD
        grep -n "XAUUSD\|xauusd\|InpTrade\|Inp.*XAUUSD" "$f" 2>/dev/null
        echo "--- All input params: ---"
        # Show lines between <inputs> and </inputs> or expert params section
        sed -n '/^<inputs>/,/<\/inputs>/p' "$f" 2>/dev/null | head -40
        # Also try alternative format
        grep -A100 "^<expert>" "$f" 2>/dev/null | grep -B1 -A1 "XAUUSD\|inputs" | head -20
    fi
done

# Also check .set files (preset files)
echo ""
echo "=== PRESET FILES ==="
find "$MT5" -name "*.set" 2>/dev/null | while read f; do
    if grep -q "PropFirmBot\|XAUUSD" "$f" 2>/dev/null; then
        echo "Found: $f"
        grep -i "XAUUSD\|InpTrade" "$f" 2>/dev/null
    fi
done

# Check tester directory too
echo ""
echo "=== LAST USED INPUTS ==="
find "$MT5" -path "*/Tester/*" -name "*.set" 2>/dev/null | while read f; do
    if grep -q "PropFirmBot\|InpTrade" "$f" 2>/dev/null; then
        echo "Found: $f"
        grep -i "XAUUSD\|InpTrade" "$f" 2>/dev/null
    fi
done

echo ""
echo "=== DONE ==="
