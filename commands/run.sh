#!/bin/bash
# FULL FIX: Remove DLL EA, recompile clean EA, restart MT5, enable AutoTrading via xdotool
echo "=== FULL BOT FIX $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
REPO="/root/MT5-PropFirm-Bot"

# Step 1: Pull latest code (with DLL removed)
echo "[1] Pulling latest code from repo..."
cd "$REPO"
git pull origin claude/check-bot-update-status-KDu5H 2>&1 | tail -5

# Step 2: Copy updated EA files (no DLL imports)
echo "[2] Deploying clean EA files..."
cp -v "$REPO/EA/"*.mq5 "$EA_DIR/" 2>&1
cp -v "$REPO/EA/"*.mqh "$EA_DIR/" 2>&1

# Step 3: Delete old .ex5 to force recompile
echo "[3] Removing old .ex5..."
rm -f "$EA_DIR/PropFirmBot.ex5"

# Step 4: Compile with MetaEditor
echo "[4] Compiling EA..."
cd "$MT5"
wine MetaEditor64.exe /compile:"MQL5/Experts/PropFirmBot/PropFirmBot.mq5" /log 2>/dev/null
sleep 8

# Check compile result
if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
    SIZE=$(stat -c%s "$EA_DIR/PropFirmBot.ex5")
    echo "    COMPILED OK - Size: $SIZE bytes"
else
    echo "    COMPILE FAILED - no .ex5 file"
fi

# Show compile log if exists
COMPILE_LOG="$MT5/MQL5/Experts/PropFirmBot/PropFirmBot.log"
if [ -f "$COMPILE_LOG" ]; then
    echo "    Compile log:"
    cat "$COMPILE_LOG" 2>/dev/null | tr -d '\0' | tail -5
fi

# Step 5: Kill MT5
echo "[5] Stopping MT5..."
pkill -f terminal64.exe 2>/dev/null || true
sleep 3

# Step 6: Fix config files - ensure DLL is NOT required but AutoTrading is set
echo "[6] Updating config files..."
STARTUP="$MT5/config/startup.ini"
if [ -f "$STARTUP" ]; then
    # Keep AllowDllImport=0 since we removed DLL imports
    sed -i 's/AllowDllImport=1/AllowDllImport=0/' "$STARTUP"
    echo "    startup.ini: AllowDllImport set to 0 (not needed anymore)"
    cat "$STARTUP"
fi

# Step 7: Start MT5
echo "[7] Starting MT5..."
cd "$MT5"
wine terminal64.exe /portable &
sleep 12

# Step 8: Enable AutoTrading with xdotool (single Ctrl+E to first window)
echo "[8] Enabling AutoTrading via xdotool..."

# Find the main MT5 window
MT5_WIN=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
if [ -z "$MT5_WIN" ]; then
    MT5_WIN=$(xdotool search --name "MetaTrader" 2>/dev/null | head -1)
fi
if [ -z "$MT5_WIN" ]; then
    MT5_WIN=$(xdotool search --name "terminal64" 2>/dev/null | head -1)
fi

if [ -n "$MT5_WIN" ]; then
    echo "    Found MT5 window: $MT5_WIN"
    # Send exactly ONE Ctrl+E to toggle AutoTrading ON
    xdotool key --window "$MT5_WIN" ctrl+e
    echo "    Sent Ctrl+E to enable AutoTrading"
    sleep 3
else
    echo "    WARNING: No MT5 window found!"
    echo "    All windows:"
    xdotool search --name "" 2>/dev/null | head -10
fi

# Step 9: Create persistent fix script for reboots
echo "[9] Setting up persistent AutoTrading fix..."
cat > /root/fix_autotrading.sh << 'FIXEOF'
#!/bin/bash
# Wait for MT5 to fully start
sleep 30
export DISPLAY=:99
MT5_WIN=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
if [ -z "$MT5_WIN" ]; then
    MT5_WIN=$(xdotool search --name "MetaTrader" 2>/dev/null | head -1)
fi
if [ -n "$MT5_WIN" ]; then
    xdotool key --window "$MT5_WIN" ctrl+e
    echo "$(date): AutoTrading enabled via Ctrl+E on window $MT5_WIN" >> /var/log/autotrading_fix.log
fi
FIXEOF
chmod +x /root/fix_autotrading.sh

# Add to crontab if not already there
(crontab -l 2>/dev/null | grep -v fix_autotrading; echo "@reboot /root/fix_autotrading.sh") | crontab -

# Step 10: Verify
echo "[10] Verifying..."
sleep 5

# Check EA log
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$EALOG" ]; then
    echo "    Latest EA log entries:"
    cat "$EALOG" 2>/dev/null | tr -d '\0' | grep -i "INIT\|ALL SYSTEMS\|AutoTrading\|automated trading\|DLL\|error\|AUTOFIX" | tail -10
    echo ""
    echo "    Last 10 lines:"
    cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -10
fi

# Check status
echo ""
echo "[11] Bot Status:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null | head -15

echo "=== DONE $(date -u) ==="
