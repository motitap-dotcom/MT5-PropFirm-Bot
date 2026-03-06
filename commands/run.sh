#!/bin/bash
# =============================================================
# FIX: Enable AutoTrading in MT5 (Ctrl+E shortcut)
# =============================================================

echo "============================================"
echo "  FIX: Enable AutoTrading"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. Check current MT5 process
echo "=== [1] MT5 Process ==="
MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
if [ -z "$MT5_PID" ]; then
    echo "*** MT5 is NOT running! Starting it... ***"
    cd "/root/.wine/drive_c/Program Files/MetaTrader 5"
    wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server /autotrading &
    sleep 10
    MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
fi
echo "MT5 PID: $MT5_PID"
echo ""

# 2. Install xdotool if not present
echo "=== [2] Install xdotool ==="
which xdotool > /dev/null 2>&1 || apt-get install -y xdotool 2>&1
echo ""

# 3. Find MT5 window
echo "=== [3] Find MT5 Window ==="
MT5_WINDOW=$(xdotool search --name "MetaTrader" 2>/dev/null | head -1)
if [ -z "$MT5_WINDOW" ]; then
    MT5_WINDOW=$(xdotool search --name "terminal64" 2>/dev/null | head -1)
fi
if [ -z "$MT5_WINDOW" ]; then
    MT5_WINDOW=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
fi
if [ -z "$MT5_WINDOW" ]; then
    echo "Trying to find any Wine window..."
    MT5_WINDOW=$(xdotool search --class "Wine" 2>/dev/null | head -1)
fi
echo "MT5 Window ID: $MT5_WINDOW"
echo ""

# 4. Send Ctrl+E to toggle AutoTrading ON
echo "=== [4] Send Ctrl+E (AutoTrading toggle) ==="
if [ -n "$MT5_WINDOW" ]; then
    # Focus the window first
    xdotool windowactivate --sync "$MT5_WINDOW" 2>&1
    sleep 1

    # Send Ctrl+E to enable AutoTrading
    xdotool key --window "$MT5_WINDOW" ctrl+e 2>&1
    echo "Sent Ctrl+E to window $MT5_WINDOW"
    sleep 2

    # Send it again just in case (toggle) - but we need to check state
    # Actually let's just send once and check the logs
    echo "AutoTrading toggle sent!"
else
    echo "*** Could not find MT5 window! ***"
    echo "All windows on display :99:"
    xdotool search --name "" 2>/dev/null | while read wid; do
        echo "  Window $wid: $(xdotool getwindowname $wid 2>/dev/null)"
    done
fi
echo ""

# 5. Also try to enable via Wine registry (alternative method)
echo "=== [5] Wine Registry AutoTrading ==="
# MT5 stores AutoTrading state - let's check
COMMON_INI="/root/.wine/drive_c/Program Files/MetaTrader 5/config/common.ini"
if [ -f "$COMMON_INI" ]; then
    echo "Current common.ini:"
    cat "$COMMON_INI"
    # Enable AutoTrading in ini
    if grep -q "AutoTrading" "$COMMON_INI"; then
        sed -i 's/AutoTrading=0/AutoTrading=1/g' "$COMMON_INI"
        echo "Updated AutoTrading=1 in common.ini"
    fi
else
    echo "No common.ini found at expected path"
    # Search for it
    find "/root/.wine/drive_c/Program Files/MetaTrader 5/" -name "common.ini" -o -name "*.ini" 2>/dev/null | head -10
fi
echo ""

# 6. Check all .ini files for AutoTrading setting
echo "=== [6] Search for AutoTrading in all config files ==="
find "/root/.wine/drive_c/Program Files/MetaTrader 5/" -name "*.ini" -exec grep -l -i "autotrad" {} \; 2>/dev/null
find "/root/.wine/drive_c/Program Files/MetaTrader 5/" -name "*.ini" -exec echo "--- {} ---" \; -exec grep -i "autotrad\|ExpertEnabled\|expert" {} \; 2>/dev/null
echo ""

# 7. Wait and check logs for new activity
echo "=== [7] Wait for next bar and check ==="
sleep 5
LOG_FILE="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs/20260306.log"
echo "Last 20 log lines:"
tail -20 "$LOG_FILE" 2>/dev/null
echo ""

echo "============================================"
echo "  FIX COMPLETE $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""
echo "NOTE: If AutoTrading is still disabled, Noa needs to:"
echo "1. Connect via VNC (RealVNC to 77.237.234.2:5900)"
echo "2. Click the 'AutoTrading' button in MT5 toolbar (or press Ctrl+E)"
echo "3. Also go to Tools > Options > Expert Advisors:"
echo "   - Check 'Allow Algorithmic Trading'"
echo "   - Check 'Allow WebRequest for listed URL'"
echo "   - Add: https://api.telegram.org"
