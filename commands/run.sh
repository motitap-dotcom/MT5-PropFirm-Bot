#!/bin/bash
# Fix bot: deploy clean EA, compile, then restart MT5 fully detached
echo "=== FIX $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
REPO="/root/MT5-PropFirm-Bot"

# Pull & deploy
cd "$REPO" && git pull origin claude/check-bot-update-status-KDu5H 2>&1 | tail -2
cp "$REPO/EA/"*.mq5 "$EA_DIR/" && cp "$REPO/EA/"*.mqh "$EA_DIR/" && echo "Files copied"

# Compile
rm -f "$EA_DIR/PropFirmBot.ex5"
cd "$MT5"
timeout 15 wine MetaEditor64.exe /compile:"MQL5/Experts/PropFirmBot/PropFirmBot.mq5" /log 2>/dev/null
sleep 3
[ -f "$EA_DIR/PropFirmBot.ex5" ] && echo "COMPILED: $(stat -c%s "$EA_DIR/PropFirmBot.ex5") bytes" || echo "COMPILE FAILED"

# Kill MT5
pkill -f terminal64.exe 2>/dev/null
sleep 2

# Create restart+autotrading script and run it fully detached via at/setsid
cat > /tmp/restart_mt5.sh << 'SCRIPT'
#!/bin/bash
export DISPLAY=:99
cd "/root/.wine/drive_c/Program Files/MetaTrader 5"
wine terminal64.exe /portable &
sleep 15
W=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
[ -z "$W" ] && W=$(xdotool search --name "MetaTrader" 2>/dev/null | head -1)
[ -n "$W" ] && xdotool key --window "$W" ctrl+e && echo "$(date): AutoTrading enabled" >> /var/log/autotrading_fix.log
SCRIPT
chmod +x /tmp/restart_mt5.sh

# Launch fully detached - setsid + redirect all FDs + disown
setsid /tmp/restart_mt5.sh </dev/null >/dev/null 2>&1 &
echo "MT5 restart launched in background (PID: $!)"

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

echo "MT5 will start in background. Check status in ~20 seconds."
echo "=== DONE $(date -u) ==="
