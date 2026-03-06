#!/bin/bash
# Fix MT5 startup: create proper start script and fix systemd service
echo "=== FIX MT5 SERVICE $(date -u) ==="
export DISPLAY=:99

# Step 1: Create start script that systemd will use
echo "[1] Creating MT5 start script..."
cat > /root/start_mt5.sh << 'STARTEOF'
#!/bin/bash
export DISPLAY=:99
export WINEPREFIX=/root/.wine
cd "/root/.wine/drive_c/Program Files/MetaTrader 5"
exec wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server
STARTEOF
chmod +x /root/start_mt5.sh

# Step 2: Create proper autotrading fix script
echo "[2] Creating AutoTrading fix script..."
cat > /root/fix_autotrading.sh << 'FIXEOF'
#!/bin/bash
export DISPLAY=:99
sleep 25
W=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
if [ -n "$W" ]; then
    xdotool windowactivate --sync "$W" 2>/dev/null
    sleep 1
    xdotool key ctrl+e
    echo "$(date): Ctrl+E sent to $W" >> /var/log/autotrading_fix.log
else
    echo "$(date): No window found" >> /var/log/autotrading_fix.log
fi
FIXEOF
chmod +x /root/fix_autotrading.sh

# Step 3: Fix systemd service - use script instead of inline command
echo "[3] Fixing systemd service..."
cat > /etc/systemd/system/mt5.service << 'SVCEOF'
[Unit]
Description=MetaTrader 5 Trading Terminal
After=network.target xvfb.service
Requires=xvfb.service

[Service]
Type=simple
User=root
Environment=DISPLAY=:99
Environment=WINEPREFIX=/root/.wine
ExecStartPre=/bin/sleep 5
ExecStart=/root/start_mt5.sh
Restart=on-failure
RestartSec=30
StartLimitIntervalSec=600
StartLimitBurst=10

[Install]
WantedBy=multi-user.target
SVCEOF
systemctl daemon-reload

# Step 4: Stop everything and restart
echo "[4] Stopping MT5..."
systemctl stop mt5 2>/dev/null
pkill -f terminal64.exe 2>/dev/null
pkill -9 -f "wine.*terminal" 2>/dev/null
sleep 3

echo "[5] Starting MT5 service..."
systemctl start mt5 &
sleep 15

# Check if running
echo "[6] Process check:"
pgrep -a terminal64 2>/dev/null || echo "terminal64 not found"
pgrep -a wine 2>/dev/null | head -3 || echo "wine not found"
ps aux | grep -i "terminal\|wine" | grep -v grep | head -5

echo "[7] Service status:"
systemctl status mt5 --no-pager 2>/dev/null | head -8

# Step 5: Try AutoTrading toggle
echo "[8] AutoTrading toggle..."
W=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
echo "  Window: $W"
if [ -n "$W" ]; then
    xdotool windowactivate --sync "$W" 2>/dev/null
    sleep 1
    xdotool key ctrl+e
    echo "  Ctrl+E sent!"
else
    echo "  No FundedNext window yet - scheduling background fix..."
    nohup /root/fix_autotrading.sh </dev/null >/dev/null 2>&1 &
    disown $!
fi

sleep 3
echo "[9] Latest EA log:"
EALOG=$(ls -t "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -5

echo "=== DONE $(date -u) ==="
