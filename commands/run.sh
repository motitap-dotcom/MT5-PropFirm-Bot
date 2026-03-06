#!/bin/bash
# Simple: ensure MT5 running + single Ctrl+E
echo "=== QUICK FIX $(date -u) ==="
export DISPLAY=:99
export WINEPREFIX=/root/.wine
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# Ensure MT5 is running
if ! pgrep -f terminal64 > /dev/null; then
    echo "MT5 not running, starting..."
    pgrep Xvfb || Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
    nohup wine "$MT5/terminal64.exe" /portable /login:11797849 /server:FundedNext-Server /autotrading > /dev/null 2>&1 &
    sleep 20
fi
echo "MT5: $(pgrep -f terminal64 | wc -l) processes"

# Single Ctrl+E to first FundedNext window
WIN=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
echo "Window: $WIN"
if [ -n "$WIN" ]; then
    xdotool windowactivate --sync "$WIN" 2>/dev/null
    sleep 1
    xdotool key --clearmodifiers ctrl+e
    echo "Ctrl+E sent"
fi
sleep 5

# Check log
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
tail -5 "$EALOG" 2>&1

# Create persistent fix script
cat > /root/fix_autotrading.sh << 'EOF'
#!/bin/bash
export DISPLAY=:99
sleep 30
WIN=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
[ -n "$WIN" ] && xdotool windowactivate --sync "$WIN" 2>/dev/null && sleep 1 && xdotool key --clearmodifiers ctrl+e
echo "$(date): AutoTrading toggled" >> /var/log/autotrading_fix.log
EOF
chmod +x /root/fix_autotrading.sh
echo "Persistent fix script created"

echo "=== DONE $(date -u) ==="
