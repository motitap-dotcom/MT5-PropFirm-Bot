#!/bin/bash
# Fix chart file with proper UTF-16 encoding preservation
echo "=== UTF16 FIX $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# Kill MT5
screen -X -S mt5 quit 2>/dev/null
pkill -9 -f "terminal64\|start.exe" 2>/dev/null
sleep 3

CHART="$MT5/MQL5/Profiles/Charts/Default/chart01.chr"

echo "[1] Current state:"
file "$CHART" 2>/dev/null
cat "$CHART" 2>/dev/null | tr -d '\0' | grep "expertmode"

echo "[2] Proper UTF-16 fix..."
# Convert UTF-16LE → UTF-8, fix, convert back to UTF-16LE with BOM
iconv -f UTF-16LE -t UTF-8 "$CHART" 2>/dev/null > /tmp/chart_utf8.chr
# If iconv fails (file might already be UTF-8 from our previous strip), try direct
if [ ! -s /tmp/chart_utf8.chr ]; then
    cat "$CHART" | tr -d '\0' > /tmp/chart_utf8.chr
fi
# Replace expertmode
sed -i 's/expertmode=0/expertmode=3/g' /tmp/chart_utf8.chr
sed -i 's/expertmode=1$/expertmode=3/g' /tmp/chart_utf8.chr
echo "  After sed:"
grep "expertmode" /tmp/chart_utf8.chr
# Convert back to UTF-16LE
printf '\xff\xfe' > "$CHART"  # BOM
iconv -f UTF-8 -t UTF-16LE /tmp/chart_utf8.chr >> "$CHART"
echo "  File type:"
file "$CHART"

# Also fix other chart files
for D in "$MT5/MQL5/Profiles/Charts/Default" "$MT5/Profiles/Charts/Default"; do
    for f in "$D/"*.chr; do
        [ -f "$f" ] || continue
        [ "$f" = "$CHART" ] && continue
        CONTENT=$(cat "$f" 2>/dev/null | tr -d '\0')
        if echo "$CONTENT" | grep -q "expertmode=0"; then
            echo "$CONTENT" | sed 's/expertmode=0/expertmode=3/g' > /tmp/chr_tmp.chr
            printf '\xff\xfe' > "$f"
            iconv -f UTF-8 -t UTF-16LE /tmp/chr_tmp.chr >> "$f"
            echo "  Also fixed: $(basename "$f")"
        fi
    done
done

# Start MT5
echo "[3] Starting MT5..."
cd "$MT5"
screen -dmS mt5 bash -c 'export DISPLAY=:99 && export WINEPREFIX=/root/.wine && wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server 2>&1'
echo "  Waiting 30s for full load..."
sleep 30

echo "[4] Windows check:"
xdotool search --name "" 2>/dev/null | while read w; do
    NAME=$(xdotool getwindowname "$w" 2>/dev/null)
    [ -n "$NAME" ] && [ "$NAME" != "Default IME" ] && echo "  $w: $NAME"
done

echo "[5] Enable AutoTrading..."
wine "C:\\at_keybd.exe" 2>&1
sleep 8

echo "[6] Result:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -5
echo "  Last 8 lines:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -8

echo "=== DONE $(date -u) ==="
