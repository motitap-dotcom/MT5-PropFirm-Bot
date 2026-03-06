#!/bin/bash
# Check current state and try multiple methods to enable AutoTrading
echo "=== AUTOTRADING DEBUG $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "[1] MT5 process:"
pgrep -a terminal64 2>/dev/null || echo "NOT FOUND via pgrep"
ps aux | grep -i "terminal64\|wine.*terminal" | grep -v grep | head -3

echo "[2] Screen sessions:"
screen -ls 2>/dev/null

echo "[3] Latest EA log (last 10 lines):"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
echo "  File: $EALOG"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -10

echo "[4] MT5 config files with AutoTrading:"
for f in "$MT5/config/"*.ini "$MT5/"*.ini; do
    if [ -f "$f" ]; then
        echo "  --- $(basename "$f") ---"
        cat "$f" 2>/dev/null | tr -d '\0' | grep -i "auto\|trading\|dll\|expert" | head -5
    fi
done

echo "[5] Chart profile expertmode:"
find "$MT5" -name "*.chr" 2>/dev/null | head -3 | while read f; do
    echo "  --- $f ---"
    cat "$f" 2>/dev/null | tr -d '\0' | grep -i "expert" | head -3
done

echo "[6] Terminal data path:"
# Check the MQL5 terminal log for data path
TERMLOG=$(ls -t "$MT5/Logs/"*.log 2>/dev/null | head -1)
echo "  Terminal log: $TERMLOG"
cat "$TERMLOG" 2>/dev/null | tr -d '\0' | grep -i "data\|path\|auto\|trading" | head -5

echo "[7] Try to fix AutoTrading via ini file:"
# Find and modify the correct ini file
for f in "$MT5/config/common.ini" "$MT5/terminal64.ini" "$MT5/config/terminal.ini"; do
    if [ -f "$f" ]; then
        echo "  Modifying $f..."
        # Check encoding
        file "$f"
        # Add/update AutoTrading setting
        if file "$f" | grep -q "UTF-16\|BOM"; then
            # UTF-16 file - handle specially
            iconv -f UTF-16LE -t UTF-8 "$f" 2>/dev/null | sed 's/AutoTrading=0/AutoTrading=1/' | iconv -f UTF-8 -t UTF-16LE > "/tmp/fixed_ini.tmp" && cp "/tmp/fixed_ini.tmp" "$f"
            echo "  Fixed (UTF-16)"
        else
            sed -i 's/AutoTrading=0/AutoTrading=1/' "$f"
            if ! grep -q "AutoTrading" "$f" 2>/dev/null; then
                echo -e "\n[Common]\nAutoTrading=1" >> "$f"
            fi
            echo "  Fixed (UTF-8)"
        fi
    fi
done

echo "[8] Try keyboard shortcut with different methods:"
W=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
echo "  Window: $W"
if [ -n "$W" ]; then
    # Method 1: windowfocus + key
    echo "  Method 1: windowfocus + key"
    xdotool windowfocus --sync "$W" 2>/dev/null
    sleep 1
    xdotool key ctrl+e
    sleep 2

    # Check if autotrading changed
    EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
    cat "$EALOG" 2>/dev/null | tr -d '\0' | grep -i "automated trading" | tail -3
fi

echo "[9] Current EA status:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -5

echo "=== DONE $(date -u) ==="
