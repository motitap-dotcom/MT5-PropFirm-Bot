#!/bin/bash
# STEP 1: Pull, deploy, compile, restart MT5, enable AutoTrading - FAST version
echo "=== FULL FIX $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
REPO="/root/MT5-PropFirm-Bot"

# Pull latest
cd "$REPO" && git pull origin claude/check-bot-update-status-KDu5H 2>&1 | tail -3

# Deploy EA files
cp "$REPO/EA/"*.mq5 "$EA_DIR/" && cp "$REPO/EA/"*.mqh "$EA_DIR/" && echo "EA files copied"

# Remove old .ex5 and compile
rm -f "$EA_DIR/PropFirmBot.ex5"
cd "$MT5" && wine MetaEditor64.exe /compile:"MQL5/Experts/PropFirmBot/PropFirmBot.mq5" /log 2>/dev/null
sleep 6
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null && echo "COMPILE OK" || echo "COMPILE FAILED"

# Kill MT5 and restart
pkill -f terminal64.exe 2>/dev/null; sleep 2
cd "$MT5" && wine terminal64.exe /portable &
sleep 10

# Enable AutoTrading - single Ctrl+E
MT5_WIN=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
[ -z "$MT5_WIN" ] && MT5_WIN=$(xdotool search --name "MetaTrader" 2>/dev/null | head -1)
if [ -n "$MT5_WIN" ]; then
    xdotool key --window "$MT5_WIN" ctrl+e
    echo "Ctrl+E sent to window $MT5_WIN"
else
    echo "NO MT5 WINDOW FOUND"
    xdotool search --name "" 2>/dev/null | while read w; do xdotool getwindowname "$w" 2>/dev/null; done | head -10
fi

# Setup reboot fix
cat > /root/fix_autotrading.sh << 'EOF'
#!/bin/bash
sleep 30; export DISPLAY=:99
W=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
[ -z "$W" ] && W=$(xdotool search --name "MetaTrader" 2>/dev/null | head -1)
[ -n "$W" ] && xdotool key --window "$W" ctrl+e
EOF
chmod +x /root/fix_autotrading.sh
(crontab -l 2>/dev/null | grep -v fix_autotrading; echo "@reboot /root/fix_autotrading.sh") | crontab -

sleep 3

# Check results
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
echo "--- EA LOG ---"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep -i "INIT\|ALL SYSTEMS\|automated trading\|DLL\|error" | tail -8
echo "--- STATUS ---"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null | head -12
echo "=== DONE $(date -u) ==="
