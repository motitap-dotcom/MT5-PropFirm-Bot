#!/bin/bash
# Quick fix: Enable AutoTrading and restart MT5
echo "=== FIX AutoTrading $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# Stop MT5
echo "[1] Stopping MT5..."
pkill -f terminal64 2>/dev/null
sleep 5

# Fix terminal.ini
echo "[2] Fixing configs..."
INI="$MT5/terminal.ini"
if [ -f "$INI" ]; then
    # Show current state
    echo "Current terminal.ini AutoTrading lines:"
    grep -in "autotrad\|ExpertEnable" "$INI" || echo "(none found)"

    # Ensure AutoTrading=1 exists
    if grep -q "AutoTrading=" "$INI"; then
        sed -i 's/AutoTrading=0/AutoTrading=1/g' "$INI"
    else
        # Add to end
        echo "AutoTrading=1" >> "$INI"
    fi

    if grep -q "ExpertEnabled=" "$INI"; then
        sed -i 's/ExpertEnabled=0/ExpertEnabled=1/g' "$INI"
    fi

    echo "After fix:"
    grep -in "autotrad\|ExpertEnable" "$INI" || echo "(none)"
fi

# Fix common.ini
CINI="$MT5/config/common.ini"
if [ -f "$CINI" ]; then
    echo "Fixing common.ini..."
    if grep -q "AutoTrading=" "$CINI"; then
        sed -i 's/AutoTrading=0/AutoTrading=1/g' "$CINI"
    else
        echo "AutoTrading=1" >> "$CINI"
    fi
fi

# Fix chart files - enable EA auto trading per chart
echo "[3] Fixing chart configs..."
find "$MT5/profiles" -name "*.chr" 2>/dev/null | while read f; do
    sed -i 's/ExpertAutoTrading=0/ExpertAutoTrading=1/g' "$f" 2>/dev/null
    echo "Fixed: $(basename $f)"
done

# Restart MT5
echo "[4] Starting MT5..."
export DISPLAY=:99
export WINEPREFIX=/root/.wine
nohup wine "$MT5/terminal64.exe" /portable /login:11797849 /server:FundedNext-Server /autotrading > /dev/null 2>&1 &
sleep 8

# Check
echo "[5] Verify..."
if pgrep -f terminal64 > /dev/null; then
    echo "MT5 RUNNING OK"
else
    echo "MT5 NOT RUNNING - trying again"
    # Make sure Xvfb is running
    pgrep Xvfb || Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
    nohup wine "$MT5/terminal64.exe" /portable /login:11797849 /server:FundedNext-Server /autotrading > /dev/null 2>&1 &
    sleep 8
    pgrep -f terminal64 && echo "MT5 RUNNING (2nd try)" || echo "MT5 FAILED"
fi

echo "=== DONE $(date -u) ==="
