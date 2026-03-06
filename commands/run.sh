#!/bin/bash
# Restart MT5 properly and enable AutoTrading
echo "=== RESTART MT5 $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# Kill any existing MT5
pkill -f terminal64.exe 2>/dev/null
sleep 2

# Check startup config
echo "[1] MT5 service:"
systemctl status mt5 2>/dev/null | head -5 || echo "No mt5 service"
echo "[2] Startup scripts:"
ls /root/start_mt5*.sh 2>/dev/null; cat /root/start_mt5.sh 2>/dev/null | head -10 || echo "None"
echo "[3] Crontab:"
crontab -l 2>/dev/null | head -5
echo "[4] Display:"
pgrep -a Xvfb 2>/dev/null || echo "No Xvfb"

# Start MT5 fully detached
echo "[5] Starting MT5..."
cd "$MT5"
wine terminal64.exe /portable </dev/null >/dev/null 2>&1 &
disown $!
echo "MT5 launched (detached)"

# Wait for init, then check windows and send Ctrl+E
# Do this in a background script that runs after SSH exits
cat > /tmp/enable_autotrading.sh << 'ATEOF'
#!/bin/bash
export DISPLAY=:99
sleep 15
# List windows
echo "=== Windows at $(date -u) ===" >> /tmp/at_log.txt
xdotool search --name "" 2>/dev/null | while read w; do
    NAME=$(xdotool getwindowname "$w" 2>/dev/null)
    [ -n "$NAME" ] && echo "  $w: $NAME" >> /tmp/at_log.txt
done

# Find MT5 window
for PATTERN in "FundedNext" "MetaTrader" "terminal" "MT5" "EURUSD"; do
    W=$(xdotool search --name "$PATTERN" 2>/dev/null | head -1)
    [ -n "$W" ] && break
done

if [ -n "$W" ]; then
    xdotool key --window "$W" ctrl+e
    echo "Ctrl+E sent to $W ($PATTERN)" >> /tmp/at_log.txt
else
    echo "No MT5 window found" >> /tmp/at_log.txt
    # Try all windows > 1000000
    for w in $(xdotool search --name "" 2>/dev/null); do
        if [ "$w" -gt 1000000 ] 2>/dev/null; then
            NAME=$(xdotool getwindowname "$w" 2>/dev/null)
            if [ ${#NAME} -gt 5 ]; then
                xdotool key --window "$w" ctrl+e
                echo "Tried Ctrl+E on $w ($NAME)" >> /tmp/at_log.txt
                break
            fi
        fi
    done
fi
ATEOF
chmod +x /tmp/enable_autotrading.sh
nohup /tmp/enable_autotrading.sh </dev/null >/dev/null 2>&1 &
disown $!
echo "AutoTrading fix scheduled in background"

echo "=== DONE $(date -u) ==="
echo "Check /tmp/at_log.txt on next run for AutoTrading result"
