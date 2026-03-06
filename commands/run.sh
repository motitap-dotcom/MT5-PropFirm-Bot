#!/bin/bash
# Restart MT5 + immediate Ctrl+E (works only right after start)
echo "=== RESTART + CTRL+E $(date -u) ==="
export DISPLAY=:99
export WINEPREFIX=/root/.wine
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# Kill MT5
pkill -f terminal64 2>/dev/null
sleep 3
pkill -9 -f terminal64 2>/dev/null
sleep 2

# Start MT5
pgrep Xvfb || (Xvfb :99 -screen 0 1280x1024x24 & sleep 2)
nohup wine "$MT5/terminal64.exe" /portable /login:11797849 /server:FundedNext-Server /autotrading > /dev/null 2>&1 &
echo "MT5 starting..."
sleep 20

# Find window and send SINGLE Ctrl+E to FIRST window ONLY
WIN=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
echo "Window: $WIN"
xdotool windowfocus --sync "$WIN" 2>/dev/null
sleep 1
xdotool windowactivate --sync "$WIN" 2>/dev/null
sleep 1
xdotool key --window "$WIN" --clearmodifiers ctrl+e 2>/dev/null
echo "Ctrl+E sent"
sleep 5

# Check
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3
echo ""

# Save state and update persistent fix
cat > /root/fix_autotrading.sh << 'FIXEOF'
#!/bin/bash
export DISPLAY=:99
sleep 25
WIN=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
[ -n "$WIN" ] && xdotool windowfocus --sync "$WIN" 2>/dev/null && sleep 1 && xdotool windowactivate --sync "$WIN" 2>/dev/null && sleep 1 && xdotool key --window "$WIN" --clearmodifiers ctrl+e 2>/dev/null
echo "$(date): Toggled AutoTrading on $WIN" >> /var/log/autotrading_fix.log
FIXEOF
chmod +x /root/fix_autotrading.sh

# Add to crontab for reboot
(crontab -l 2>/dev/null | grep -v fix_autotrading; echo "@reboot /root/fix_autotrading.sh") | crontab -
echo "Persistent fix installed"

echo "=== DONE $(date -u) ==="
