#!/bin/bash
# Fix AutoTrading: activate window first, then Ctrl+E, fix systemd service
echo "=== AUTOTRADING FIX $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# First: fix systemd service to use Type=forking so MT5 stays running
echo "[1] Fixing systemd service..."
cat > /etc/systemd/system/mt5.service << 'SVCEOF'
[Unit]
Description=MetaTrader 5 Trading Terminal
After=network.target xvfb.service
Requires=xvfb.service

[Service]
Type=forking
User=root
Environment=DISPLAY=:99
Environment=WINEPREFIX=/root/.wine
ExecStartPre=/bin/sleep 5
ExecStart=/bin/bash -c 'cd "/root/.wine/drive_c/Program Files/MetaTrader 5" && wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server &'
ExecStartPost=/bin/bash -c "sleep 20 && /root/fix_autotrading.sh &"
Restart=on-failure
RestartSec=30
StartLimitIntervalSec=600
StartLimitBurst=10
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVCEOF
systemctl daemon-reload

# Kill ALL MT5 instances and wine
echo "[2] Stopping everything..."
systemctl stop mt5 2>/dev/null
pkill -f terminal64.exe 2>/dev/null
pkill -f "wine.*terminal" 2>/dev/null
sleep 3

# Update fix_autotrading.sh - activate window before Ctrl+E
echo "[3] Updating AutoTrading fix script..."
cat > /root/fix_autotrading.sh << 'FIXEOF'
#!/bin/bash
export DISPLAY=:99
# Wait for MT5 to fully load
sleep 20
# Find MT5 main window
W=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
if [ -n "$W" ]; then
    # ACTIVATE window first, then send Ctrl+E
    xdotool windowactivate --sync "$W" 2>/dev/null
    sleep 1
    xdotool key --window "$W" ctrl+e
    echo "$(date): Ctrl+E sent to activated window $W" >> /var/log/autotrading_fix.log
else
    echo "$(date): No FundedNext window found" >> /var/log/autotrading_fix.log
fi
FIXEOF
chmod +x /root/fix_autotrading.sh

# Start MT5 via systemd
echo "[4] Starting MT5 via systemd..."
systemctl start mt5
sleep 20

# Now manually try to enable AutoTrading
echo "[5] Manual AutoTrading enable..."
W=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
echo "  Found window: $W"
if [ -n "$W" ]; then
    WNAME=$(xdotool getwindowname "$W" 2>/dev/null)
    echo "  Window name: $WNAME"
    xdotool windowactivate --sync "$W" 2>/dev/null
    sleep 1
    xdotool key ctrl+e
    echo "  Ctrl+E sent (after activate)"
fi

sleep 5

# Check result
echo "[6] EA log check:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep -i "INIT\|ALL SYSTEMS\|automated trading\|error.*10027\|auto trading" | tail -10

echo "[7] MT5 process:"
pgrep -a terminal64 2>/dev/null || echo "NOT RUNNING"

echo "[8] Service status:"
systemctl status mt5 2>/dev/null | head -5

echo "=== DONE $(date -u) ==="
