#!/bin/bash
# Clean restart + immediate Ctrl+E with proper focus
echo "=== CLEAN FIX $(date -u) ==="

export DISPLAY=:99
export WINEPREFIX=/root/.wine
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. Kill EVERYTHING
echo "[1] Killing all MT5/Wine..."
pkill -9 -f terminal64 2>/dev/null
pkill -9 -f wine 2>/dev/null
pkill -9 -f wineserver 2>/dev/null
sleep 5
echo "All killed. Processes:"
pgrep -fa "terminal64\|wine" || echo "None"
echo ""

# 2. Make sure Xvfb is running
echo "[2] Display..."
pgrep Xvfb > /dev/null || (Xvfb :99 -screen 0 1280x1024x24 & sleep 2)
echo "Display ready"
echo ""

# 3. Start MT5 fresh
echo "[3] Starting MT5..."
wine "$MT5/terminal64.exe" /portable /login:11797849 /server:FundedNext-Server /autotrading &
MT5_PID=$!
echo "Started PID: $MT5_PID"
echo "Waiting 25 seconds for full load..."
sleep 25

# 4. Verify MT5 is running
pgrep -f terminal64 > /dev/null && echo "MT5 RUNNING" || echo "MT5 NOT RUNNING"
echo ""

# 5. Find the new MT5 window
echo "[5] Finding window..."
WIN_ID=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
echo "Window: $WIN_ID - $(xdotool getwindowname "$WIN_ID" 2>/dev/null)"
echo ""

# 6. Send Ctrl+E with focus
echo "[6] Sending Ctrl+E..."
if [ -n "$WIN_ID" ]; then
    # Use windowactivate (more reliable than windowfocus)
    xdotool windowactivate --sync "$WIN_ID" 2>/dev/null
    sleep 2
    xdotool key --clearmodifiers ctrl+e
    echo "Sent Ctrl+E via active window"
    sleep 5

    # Check immediately
    EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
    echo "Last 5 log lines:"
    tail -5 "$EALOG" 2>&1
fi
echo ""

# 7. Now also install a permanent fix: add autotrading toggle to mt5.service post-start
echo "[7] Creating autotrading-fix script..."
cat > /root/fix_autotrading.sh << 'SCRIPT'
#!/bin/bash
# Wait for MT5 to fully load, then enable AutoTrading via Ctrl+E
export DISPLAY=:99
sleep 30
WIN_ID=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
if [ -n "$WIN_ID" ]; then
    xdotool windowactivate --sync "$WIN_ID" 2>/dev/null
    sleep 2
    xdotool key --clearmodifiers ctrl+e
    echo "$(date): Sent Ctrl+E to $WIN_ID" >> /var/log/autotrading_fix.log
fi
SCRIPT
chmod +x /root/fix_autotrading.sh

# Add to mt5.service as ExecStartPost
MT5_SERVICE="/etc/systemd/system/mt5.service"
if [ -f "$MT5_SERVICE" ]; then
    if ! grep -q "fix_autotrading" "$MT5_SERVICE"; then
        sed -i '/ExecStart=/a ExecStartPost=/bin/bash -c "/root/fix_autotrading.sh &"' "$MT5_SERVICE" 2>/dev/null
        systemctl daemon-reload 2>/dev/null
        echo "Added autotrading fix to mt5.service"
    else
        echo "Already in mt5.service"
    fi
fi
echo ""

# 8. Wait for next bar
echo "[8] Waiting for next 15-min bar (45 seconds)..."
sleep 45

EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
echo "Latest log (last 15 lines):"
tail -15 "$EALOG" 2>&1

echo ""
echo "=== DONE $(date -u) ==="
