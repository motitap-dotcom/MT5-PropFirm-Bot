#!/bin/bash
# Full reset: disable systemd, start MT5 via screen, enable AutoTrading
echo "=== FULL RESET $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# Step 1: Kill everything and disable systemd service
echo "[1] Stopping everything..."
systemctl stop mt5 2>/dev/null
systemctl disable mt5 2>/dev/null
pkill -9 -f terminal64.exe 2>/dev/null
pkill -9 -f "wine.*terminal" 2>/dev/null
sleep 5
echo "  All MT5 processes killed"
pgrep -a terminal64 2>/dev/null && echo "  WARNING: Still running!" || echo "  Confirmed: no terminal64 running"

# Step 2: Install screen if needed
which screen >/dev/null 2>&1 || apt-get install -y -qq screen >/dev/null 2>&1

# Step 3: Start MT5 in detached screen session
echo "[2] Starting MT5 in screen..."
cd "$MT5"
screen -dmS mt5 bash -c 'export DISPLAY=:99 && export WINEPREFIX=/root/.wine && wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server 2>&1'
echo "  Screen session 'mt5' created"
screen -ls

# Step 4: Wait for MT5 to fully initialize
echo "[3] Waiting 20s for MT5 to load..."
sleep 20

# Step 5: Check windows
echo "[4] Windows:"
xdotool search --name "FundedNext" 2>/dev/null | while read w; do
    echo "  $w: $(xdotool getwindowname "$w" 2>/dev/null)"
done

# Step 6: Enable AutoTrading
echo "[5] Enabling AutoTrading..."
W=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
if [ -n "$W" ]; then
    echo "  Activating window $W..."
    xdotool windowactivate --sync "$W" 2>/dev/null
    sleep 1
    xdotool key ctrl+e
    echo "  Ctrl+E sent!"
    sleep 3
    # Check if it worked by looking at new EA log entries
    EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
    echo "[6] New EA log entries:"
    cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -10
else
    echo "  ERROR: No FundedNext window found!"
    echo "  All windows:"
    xdotool search --name "" 2>/dev/null | while read w; do
        NAME=$(xdotool getwindowname "$w" 2>/dev/null)
        [ -n "$NAME" ] && echo "    $w: $NAME"
    done
fi

# Step 7: Setup reboot persistence with screen
echo "[7] Setting up reboot persistence..."
cat > /root/start_mt5_screen.sh << 'EOF'
#!/bin/bash
export DISPLAY=:99
export WINEPREFIX=/root/.wine
sleep 10
cd "/root/.wine/drive_c/Program Files/MetaTrader 5"
screen -dmS mt5 bash -c 'export DISPLAY=:99 && export WINEPREFIX=/root/.wine && wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server 2>&1'
sleep 25
W=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
[ -n "$W" ] && xdotool windowactivate --sync "$W" 2>/dev/null && sleep 1 && xdotool key ctrl+e
EOF
chmod +x /root/start_mt5_screen.sh
(crontab -l 2>/dev/null | grep -v "fix_autotrading\|start_mt5"; echo "@reboot /root/start_mt5_screen.sh") | crontab -

echo "[8] Status:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null | head -10

echo "=== DONE $(date -u) ==="
