#!/bin/bash
# ============================================================
# PROVEN DEPLOY METHOD: Start MT5 first, then compile, then restart
# Key insight: MetaEditor ONLY works when MT5/Wine is already running
# ============================================================
echo "=== DEPLOY v4.0 $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5}/MQL5/Experts/PropFirmBot"
REPO="/root/MT5-PropFirm-Bot"
BRANCH="claude/update-server-version-3dUGg"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# Ensure display
pgrep Xvfb > /dev/null || (nohup Xvfb :99 -screen 0 1280x1024x24 >/dev/null 2>&1 & sleep 2)
pgrep x11vnc > /dev/null || nohup x11vnc -display :99 -forever -shared -rfbport 5900 -nopw >/dev/null 2>&1 &

# STEP 1: Pull latest code
echo ">>> STEP 1: Pull latest code"
cd "$REPO" && git fetch origin "$BRANCH" && git checkout "$BRANCH" && git reset --hard "origin/$BRANCH"
echo "Commit: $(git log --oneline -1)"

# STEP 2: Copy EA + config files
echo ""
echo ">>> STEP 2: Copy files"
mkdir -p "$EA_DIR" "${MT5}/MQL5/Files/PropFirmBot"
cp EA/*.mq5 EA/*.mqh "$EA_DIR/"
cp configs/*.json "${MT5}/MQL5/Files/PropFirmBot/"
echo "Copied $(ls EA/*.mq5 EA/*.mqh | wc -l) EA files + $(ls configs/*.json | wc -l) configs"

# STEP 3: Start MT5 FIRST (MetaEditor needs Wine/MT5 services running)
echo ""
echo ">>> STEP 3: Start MT5 (needed for MetaEditor to work)"
pkill -f terminal64.exe 2>/dev/null
sleep 2
nohup setsid wine "${MT5}/terminal64.exe" /portable >/dev/null 2>&1 &
disown -a
echo "Waiting for MT5 to fully start..."
sleep 15
echo "MT5: $(pgrep -f terminal64.exe > /dev/null && echo 'RUNNING' || echo 'NOT RUNNING')"

# STEP 4: Compile with MetaEditor (while MT5 is running!)
echo ""
echo ">>> STEP 4: Compile EA (with MT5 running)"
# Delete old files
rm -f "${EA_DIR}/PropFirmBot.ex5"
rm -f "${MT5}/MQL5/Experts/PropFirmBot.ex5"
rm -f "${EA_DIR}/PropFirmBot.log"

cd "${EA_DIR}"
echo "Compiling from: $(pwd)"
wine "${MT5}/metaeditor64.exe" /compile:"PropFirmBot.mq5" /log 2>/dev/null &
COMP_PID=$!
echo "MetaEditor PID: $COMP_PID"

# Wait for compile (up to 30 sec)
for i in $(seq 1 30); do
    sleep 1
    if ! kill -0 $COMP_PID 2>/dev/null; then
        echo "MetaEditor finished after ${i}s"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "MetaEditor timeout - killing"
        kill $COMP_PID 2>/dev/null
    fi
done
sleep 2

# STEP 5: Check compilation result
echo ""
echo ">>> STEP 5: Verify compilation"
EX5_FOUND=$(find "${MT5}/MQL5" -name "PropFirmBot.ex5" -type f 2>/dev/null | head -1)
if [ -n "$EX5_FOUND" ]; then
    echo "COMPILE SUCCESS!"
    echo "  Path: $EX5_FOUND"
    echo "  Size: $(stat -c%s "$EX5_FOUND") bytes"
    echo "  Date: $(stat -c%y "$EX5_FOUND")"

    # Ensure .ex5 is in EA subdirectory
    if [ "$EX5_FOUND" != "${EA_DIR}/PropFirmBot.ex5" ]; then
        cp "$EX5_FOUND" "${EA_DIR}/PropFirmBot.ex5"
        echo "  Copied to EA dir"
    fi
else
    echo "COMPILE - no .ex5 found"
    echo ""
    echo "Checking compilation log..."
    if [ -f "${EA_DIR}/PropFirmBot.log" ]; then
        echo "Log (EA dir):"
        iconv -f UTF-16LE -t UTF-8 "${EA_DIR}/PropFirmBot.log" 2>/dev/null | tail -5
    fi
    if [ -f "${MT5}/logs/metaeditor.log" ]; then
        echo "MetaEditor global log (last 10):"
        tail -10 "${MT5}/logs/metaeditor.log" 2>/dev/null
    fi

    # Search everywhere
    echo ""
    echo "Searching all .ex5 created in last 5 min..."
    find /root/.wine -name "PropFirmBot.ex5" -type f -mmin -5 -ls 2>/dev/null
    echo "Search done"
fi

# STEP 6: Restart MT5 with fresh EA
echo ""
echo ">>> STEP 6: Restart MT5 with new EA"
pkill -f terminal64.exe 2>/dev/null
sleep 3
pkill -9 -f terminal64.exe 2>/dev/null
sleep 1

nohup setsid wine "${MT5}/terminal64.exe" /portable >/dev/null 2>&1 &
disown -a
sleep 12

echo "MT5: $(pgrep -f terminal64.exe > /dev/null && echo 'RUNNING (PID: '$(pgrep -f terminal64.exe | head -1)')' || echo 'NOT RUNNING')"

# STEP 7: Verify EA loaded in MT5
echo ""
echo ">>> STEP 7: Check EA is loaded"
sleep 5
LOGFILE="${MT5}/MQL5/Logs/$(date +%Y%m%d).log"
if [ -f "$LOGFILE" ]; then
    echo "Latest EA log:"
    iconv -f UTF-16LE -t UTF-8 "$LOGFILE" 2>/dev/null | grep -i "propfirm\|init\|heartbeat\|error\|v4.0\|momentum" | tail -15
else
    echo "No EA log yet"
fi

# STEP 8: Ensure watchdog is set up
echo ""
echo ">>> STEP 8: Watchdog status"
if crontab -l 2>/dev/null | grep -q mt5_watchdog; then
    echo "Watchdog: ACTIVE"
    crontab -l 2>/dev/null | grep mt5_watchdog
else
    echo "Watchdog: NOT SET - installing..."
    cat > /root/mt5_watchdog.sh << 'WATCHDOG'
#!/bin/bash
export DISPLAY=:99
export WINEPREFIX=/root/.wine
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
pgrep Xvfb > /dev/null || (nohup Xvfb :99 -screen 0 1280x1024x24 >/dev/null 2>&1 &)
if ! pgrep -f terminal64.exe > /dev/null; then
    TS=$(date -u '+%Y-%m-%d %H:%M UTC')
    echo "${TS} - MT5 down! Restarting..." >> /root/mt5_watchdog.log
    nohup setsid wine "${MT5}/terminal64.exe" /portable >/dev/null 2>&1 &
    disown -a
    sleep 8
    if pgrep -f terminal64.exe > /dev/null; then
        echo "${TS} - Restart OK" >> /root/mt5_watchdog.log
        curl -s -X POST "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
            -d chat_id="7013213983" -d text="🔄 Watchdog: MT5 restarted at ${TS}" > /dev/null 2>&1
    else
        echo "${TS} - Restart FAILED" >> /root/mt5_watchdog.log
        curl -s -X POST "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
            -d chat_id="7013213983" -d text="🚨 Watchdog: MT5 restart FAILED at ${TS}" > /dev/null 2>&1
    fi
fi
pgrep x11vnc > /dev/null || nohup x11vnc -display :99 -forever -shared -rfbport 5900 -nopw >/dev/null 2>&1 &
WATCHDOG
    chmod +x /root/mt5_watchdog.sh
    (crontab -l 2>/dev/null | grep -v mt5_watchdog; echo "*/2 * * * * /root/mt5_watchdog.sh") | crontab -
    echo "Watchdog INSTALLED"
fi

echo ""
echo "=========================================="
echo "  DEPLOY COMPLETE $(date -u)"
echo "=========================================="
