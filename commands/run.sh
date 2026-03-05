#!/bin/bash
# Find the REAL XAUUSD symbol name + check configs
echo "=== FIND GOLD SYMBOL $(date) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. Show common.ini and startup.ini (where EA is configured)
echo "=== common.ini ==="
cat "$MT5/config/common.ini" 2>/dev/null
echo ""
echo "=== startup.ini ==="
cat "$MT5/config/startup.ini" 2>/dev/null

# 2. Find ALL available symbols - search for gold/xau
echo ""
echo "=== SEARCHING FOR GOLD/XAU SYMBOL NAME ==="
# Check symbols in bases directory
find "$MT5" -name "symbols.raw" -o -name "symgroups.raw" 2>/dev/null | while read f; do
    echo "File: $f"
    strings "$f" 2>/dev/null | grep -i "xau\|gold" | head -10
done

# Also check in any other data files
find "$MT5/Bases" -type f 2>/dev/null | while read f; do
    result=$(strings "$f" 2>/dev/null | grep -i "xau\|gold" | head -3)
    if [ -n "$result" ]; then
        echo "Found in $f: $result"
    fi
done 2>/dev/null | head -20

# 3. Check config/terminal.ini
echo ""
echo "=== terminal.ini ==="
for f in "$MT5/config/terminal.ini" "$MT5/Config/terminal.ini"; do
    if [ -f "$f" ]; then
        echo "File: $f"
        cat "$f"
    fi
done

# 4. Check the MQL5 chart profile that MT5 is actually using
echo ""
echo "=== MQL5 Default Chart Profile ==="
for f in "$MT5/MQL5/Profiles/Charts/Default/"*.chr; do
    echo "--- $f ---"
    grep -c "." "$f" 2>/dev/null
    grep "expert\|PropFirmBot\|symbol\|inputs\|InpTrade" "$f" 2>/dev/null | head -10
done 2>/dev/null

# 5. Also check the running MT5 log for symbol errors
echo ""
echo "=== RECENT MT5 LOGS (symbol errors) ==="
LOGDIR="$MT5/Logs"
if [ -d "$LOGDIR" ]; then
    ls -lt "$LOGDIR/"*.log 2>/dev/null | head -3
    LATEST=$(ls -t "$LOGDIR/"*.log 2>/dev/null | head -1)
    if [ -n "$LATEST" ]; then
        # Convert from UTF-16 and search for XAUUSD/symbol errors
        iconv -f UTF-16LE -t UTF-8 "$LATEST" 2>/dev/null | grep -i "xauusd\|gold\|symbol.*not\|cannot\|error" | tail -20
    fi
fi

# 6. Check what symbols the EA actually sees
echo ""
echo "=== EA LOGS (symbol info) ==="
EALOGDIR="$MT5/MQL5/Logs"
if [ -d "$EALOGDIR" ]; then
    LATEST=$(ls -t "$EALOGDIR/"*.log 2>/dev/null | head -1)
    if [ -n "$LATEST" ]; then
        iconv -f UTF-16LE -t UTF-8 "$LATEST" 2>/dev/null | grep -i "symbol\|XAUUSD\|gold\|Scanning\|INIT\|BuildSymbol" | tail -30
    fi
fi

echo ""
echo "=== DONE ==="
