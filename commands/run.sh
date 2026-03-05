#!/bin/bash
# AGGRESSIVE search for XAUUSD param + direct fix
echo "=== FIX XAUUSD $(date) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. Find ALL files containing InpTradeXAUUSD or TradeXAUUSD ANYWHERE
echo "=== SEARCH: Any file with InpTradeXAUUSD ==="
find "$MT5" -type f 2>/dev/null | xargs grep -rl "InpTradeXAUUSD\|TradeXAUUSD" 2>/dev/null

# 2. Find ALL .chr files (show them all, even without PropFirmBot)
echo ""
echo "=== ALL .chr FILES ==="
find "$MT5" -name "*.chr" 2>/dev/null | head -20

# 3. Find ALL chart profile directories
echo ""
echo "=== CHART PROFILE DIRS ==="
find "$MT5" -type d -name "Charts" 2>/dev/null
find "$MT5" -type d -name "Profiles" 2>/dev/null
find "$MT5" -type d -name "Default" 2>/dev/null

# 4. Find ANY file that mentions PropFirmBot (not .ex5/.mq5)
echo ""
echo "=== FILES MENTIONING PropFirmBot (config/chart only) ==="
find "$MT5" -type f \( -name "*.chr" -o -name "*.ini" -o -name "*.set" -o -name "*.cfg" -o -name "*.dat" \) 2>/dev/null | while read f; do
    if grep -q "PropFirmBot" "$f" 2>/dev/null; then
        echo "FOUND: $f"
        grep -n "PropFirmBot\|InpTrade\|XAUUSD" "$f" 2>/dev/null | head -10
        echo "---"
    fi
done

# 5. Check if XAUUSD symbol exists in market watch
echo ""
echo "=== XAUUSD SYMBOL CHECK ==="
find "$MT5" -name "symbols.raw" 2>/dev/null | while read f; do
    echo "Raw symbols file: $f ($(wc -c < "$f") bytes)"
done
# Check if XAUUSD is available on this broker
find "$MT5" -type f -name "*.raw" -o -name "*.sel" 2>/dev/null | while read f; do
    if strings "$f" 2>/dev/null | grep -q "XAUUSD"; then
        echo "XAUUSD found in: $f"
    fi
done

# 6. Show the terminal.ini for WebRequest setting
echo ""
echo "=== TERMINAL.INI ==="
INI="$MT5/terminal64.ini"
if [ -f "$INI" ]; then
    cat "$INI"
else
    echo "Not found at $INI"
    find "$MT5" -name "terminal*.ini" 2>/dev/null
fi

# 7. List ALL files in Profiles directory
echo ""
echo "=== PROFILES DIRECTORY LISTING ==="
ls -laR "$MT5/Profiles/" 2>/dev/null | head -50

echo ""
echo "=== DONE ==="
