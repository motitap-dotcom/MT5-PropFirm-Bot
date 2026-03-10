#!/bin/bash
# ============================================================
# PROVEN DEPLOY METHOD - SIMPLE & RELIABLE
# MT5 auto-compiles .mq5 files when loading - NO MetaEditor needed!
# Just: copy files → restart MT5 → verify EA loaded
# ============================================================
echo "=== DEPLOY v4.0 $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5}/MQL5/Experts/PropFirmBot"
CFG_DIR="${MT5}/MQL5/Files/PropFirmBot"
REPO="/root/MT5-PropFirm-Bot"
BRANCH="claude/update-server-version-3dUGg"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# --- STEP 1: Pull latest code ---
echo ">>> STEP 1: Pull code"
cd "$REPO"
git fetch origin "$BRANCH" 2>&1
git checkout "$BRANCH" 2>&1
git reset --hard "origin/$BRANCH" 2>&1
echo "Commit: $(git log --oneline -1)"

# --- STEP 2: Stop MT5 ---
echo ""
echo ">>> STEP 2: Stop MT5"
pkill -f terminal64.exe 2>/dev/null
sleep 3
pkill -9 -f terminal64.exe 2>/dev/null
sleep 1
echo "MT5 stopped"

# --- STEP 3: Copy files ---
echo ""
echo ">>> STEP 3: Copy EA + config files"
mkdir -p "$EA_DIR" "$CFG_DIR"
cp EA/*.mq5 EA/*.mqh "$EA_DIR/"
cp configs/*.json "$CFG_DIR/"
echo "Copied: $(ls EA/*.mq5 EA/*.mqh 2>/dev/null | wc -l) EA + $(ls configs/*.json 2>/dev/null | wc -l) config files"

# Verify source version
echo "Version in source: $(grep 'property version' "$EA_DIR/PropFirmBot.mq5" 2>/dev/null)"

# --- STEP 4: Ensure display services ---
echo ""
echo ">>> STEP 4: Display services"
pgrep Xvfb > /dev/null || (nohup Xvfb :99 -screen 0 1280x1024x24 >/dev/null 2>&1 & sleep 2)
pgrep x11vnc > /dev/null || nohup x11vnc -display :99 -forever -shared -rfbport 5900 -nopw >/dev/null 2>&1 &
echo "Xvfb: $(pgrep Xvfb > /dev/null && echo OK || echo DOWN)"
echo "VNC: $(pgrep x11vnc > /dev/null && echo OK || echo DOWN)"

# --- STEP 5: Start MT5 (it auto-compiles .mq5 when loading chart profile) ---
echo ""
echo ">>> STEP 5: Start MT5"
nohup setsid wine "${MT5}/terminal64.exe" /portable >/dev/null 2>&1 &
disown -a
echo "Waiting 20s for MT5 to start and auto-compile EA..."
sleep 20

MT5_PID=$(pgrep -f terminal64.exe | head -1)
if [ -n "$MT5_PID" ]; then
    echo "MT5: RUNNING (PID: $MT5_PID)"
else
    echo "MT5: NOT RUNNING - retry..."
    nohup setsid wine "${MT5}/terminal64.exe" /portable >/dev/null 2>&1 &
    disown -a
    sleep 15
    MT5_PID=$(pgrep -f terminal64.exe | head -1)
    echo "MT5: $([ -n "$MT5_PID" ] && echo "RUNNING (PID: $MT5_PID)" || echo "FAILED")"
fi

# --- STEP 6: Verify EA loaded (THE REAL TEST) ---
echo ""
echo ">>> STEP 6: Verify EA loaded from log"
sleep 5
LOGFILE="${MT5}/MQL5/Logs/$(date +%Y%m%d).log"
if [ -f "$LOGFILE" ]; then
    EA_LINES=$(iconv -f UTF-16LE -t UTF-8 "$LOGFILE" 2>/dev/null | grep -c "PropFirmBot")
    echo "PropFirmBot mentions in today's log: $EA_LINES"
    echo ""
    echo "--- Latest EA activity ---"
    iconv -f UTF-16LE -t UTF-8 "$LOGFILE" 2>/dev/null | grep -i "propfirm\|heartbeat\|guardian\|init\|v4.0\|momentum\|signal\|risk\|error" | tail -20
else
    echo "No EA log yet - may need more time"
fi

# --- STEP 7: Watchdog ---
echo ""
echo ">>> STEP 7: Watchdog"
# Install watchdog if not present
if ! crontab -l 2>/dev/null | grep -q mt5_watchdog; then
    cat > /root/mt5_watchdog.sh << 'WD'
#!/bin/bash
export DISPLAY=:99 WINEPREFIX=/root/.wine
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
pgrep Xvfb > /dev/null || (nohup Xvfb :99 -screen 0 1280x1024x24 >/dev/null 2>&1 &)
pgrep x11vnc > /dev/null || nohup x11vnc -display :99 -forever -shared -rfbport 5900 -nopw >/dev/null 2>&1 &
if ! pgrep -f terminal64.exe > /dev/null; then
    TS=$(date -u '+%Y-%m-%d %H:%M UTC')
    echo "${TS} - MT5 down! Restarting..." >> /root/mt5_watchdog.log
    nohup setsid wine "${MT5}/terminal64.exe" /portable >/dev/null 2>&1 &
    disown -a
    sleep 10
    if pgrep -f terminal64.exe > /dev/null; then
        echo "${TS} - Restart OK" >> /root/mt5_watchdog.log
        curl -s -X POST "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
            -d chat_id="7013213983" -d text="🔄 MT5 restarted at ${TS}" > /dev/null 2>&1
    else
        echo "${TS} - FAILED" >> /root/mt5_watchdog.log
        curl -s -X POST "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
            -d chat_id="7013213983" -d text="🚨 MT5 restart FAILED at ${TS}" > /dev/null 2>&1
    fi
fi
WD
    chmod +x /root/mt5_watchdog.sh
    (crontab -l 2>/dev/null | grep -v mt5_watchdog; echo "*/2 * * * * /root/mt5_watchdog.sh") | crontab -
fi
echo "Watchdog: $(crontab -l 2>/dev/null | grep -q mt5_watchdog && echo 'ACTIVE (every 2 min)' || echo 'NOT SET')"
echo "Watchdog log:"
tail -5 /root/mt5_watchdog.log 2>/dev/null || echo "(clean - no restarts needed)"

# --- FINAL STATUS ---
echo ""
echo "=========================================="
echo "  STATUS $(date -u)"
echo "=========================================="
echo "MT5: $(pgrep -f terminal64.exe > /dev/null && echo 'RUNNING' || echo 'DOWN')"
echo "EA source: v$(grep 'property version' "${EA_DIR}/PropFirmBot.mq5" 2>/dev/null | grep -o '"[^"]*"' | tr -d '"')"
echo "Xvfb: $(pgrep Xvfb > /dev/null && echo 'OK' || echo 'DOWN')"
echo "VNC: $(pgrep x11vnc > /dev/null && echo 'OK :5900' || echo 'DOWN')"
echo "Watchdog: $(crontab -l 2>/dev/null | grep -q mt5_watchdog && echo 'ACTIVE' || echo 'OFF')"
echo "=========================================="
