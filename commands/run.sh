#!/bin/bash
# Diagnose: is MT5 actually running? Fix if needed
echo "=== DIAGNOSE $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "[1] All wine/MT5 processes:"
ps aux | grep -i "wine\|terminal\|mt5\|start.exe\|wineserver" | grep -v grep

echo "[2] Screen sessions:"
screen -ls 2>/dev/null

echo "[3] X windows:"
xdotool search --name "" 2>/dev/null | while read w; do
    NAME=$(xdotool getwindowname "$w" 2>/dev/null)
    [ -n "$NAME" ] && [ "$NAME" != "Default IME" ] && echo "  $w: $NAME"
done

echo "[4] Xvfb + x11vnc:"
pgrep -a Xvfb 2>/dev/null
pgrep -a x11vnc 2>/dev/null

echo "[5] EA log last 5:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -5

echo "[6] AutoTrading state:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3

# If MT5 not running, restart it
if ! ps aux | grep -v grep | grep -qi "start.exe\|terminal64.exe"; then
    echo ""
    echo ">>> MT5 IS NOT RUNNING - RESTARTING..."
    screen -X -S mt5 quit 2>/dev/null
    sleep 1
    cd "$MT5"
    screen -dmS mt5 bash -c 'export DISPLAY=:99 && export WINEPREFIX=/root/.wine && wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server 2>&1'
    echo ">>> MT5 started in screen. Waiting 25s..."
    sleep 25

    echo ">>> Enabling AutoTrading..."
    wine "C:\\at_keybd.exe" 2>&1
    sleep 5

    echo ">>> Post-fix check:"
    ps aux | grep -i "start.exe\|terminal64" | grep -v grep | head -2
    cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3
    cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -5
else
    echo ""
    echo ">>> MT5 IS RUNNING"
    # Check if AutoTrading is disabled, fix if needed
    LAST=$(cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -1)
    if echo "$LAST" | grep -q "disabled"; then
        echo ">>> AutoTrading DISABLED - fixing..."
        wine "C:\\at_keybd.exe" 2>&1
        sleep 5
        cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3
    fi
fi

echo "[7] Final status:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null | head -12

echo "=== DONE $(date -u) ==="
