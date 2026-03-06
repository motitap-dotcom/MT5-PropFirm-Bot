#!/bin/bash
# Fix bot: deploy clean EA, restart MT5, enable AutoTrading
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

# Restart MT5 (nohup so SSH doesn't hang)
pkill -f terminal64.exe 2>/dev/null; sleep 2
cd "$MT5" && nohup wine terminal64.exe /portable >/dev/null 2>&1 &
disown
sleep 8

# AutoTrading toggle
MT5_WIN=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
[ -z "$MT5_WIN" ] && MT5_WIN=$(xdotool search --name "MetaTrader" 2>/dev/null | head -1)
[ -n "$MT5_WIN" ] && { xdotool key --window "$MT5_WIN" ctrl+e; echo "Ctrl+E -> $MT5_WIN"; } || echo "NO WINDOW"

# Reboot fix
cat > /root/fix_autotrading.sh << 'EOF'
#!/bin/bash
sleep 30; export DISPLAY=:99
W=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
[ -z "$W" ] && W=$(xdotool search --name "MetaTrader" 2>/dev/null | head -1)
[ -n "$W" ] && xdotool key --window "$W" ctrl+e
EOF
chmod +x /root/fix_autotrading.sh
(crontab -l 2>/dev/null | grep -v fix_autotrading; echo "@reboot /root/fix_autotrading.sh") | crontab -

sleep 5
# Verify
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
echo "--- LOG ---"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep -i "INIT\|ALL SYSTEMS\|automated\|DLL\|error" | tail -5
echo "--- STATUS ---"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null | head -10
echo "=== DONE $(date -u) ==="
