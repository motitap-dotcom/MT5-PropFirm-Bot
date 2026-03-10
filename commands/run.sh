#!/bin/bash
# ============================================================
# PropFirmBot v4.0 - FULL DEPLOY + WATCHDOG
# Proven working method - DO NOT CHANGE ORDER OF OPERATIONS
# ============================================================
echo "=========================================="
echo "  DEPLOY v4.0 - $(date -u)"
echo "=========================================="

# --- PATHS ---
REPO="/root/MT5-PropFirm-Bot"
BRANCH="claude/update-server-version-3dUGg"
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5}/MQL5/Experts/PropFirmBot"
CFG_DIR="${MT5}/MQL5/Files/PropFirmBot"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# ============================================================
# STEP 1: STOP MT5 (must be first - prevents .ex5 file lock)
# ============================================================
echo ""
echo ">>> STEP 1: Stopping MT5..."
pkill -f terminal64.exe 2>/dev/null
sleep 2
pkill -9 -f terminal64.exe 2>/dev/null
sleep 1

if pgrep -f terminal64.exe > /dev/null; then
    echo "ERROR: MT5 still running after kill attempts!"
    pkill -9 -f wine 2>/dev/null
    sleep 2
fi
echo "MT5 stopped: OK"

# ============================================================
# STEP 2: PULL LATEST CODE FROM REPO
# ============================================================
echo ""
echo ">>> STEP 2: Pulling latest code..."
cd "$REPO" || { echo "ERROR: repo not found"; exit 1; }
git fetch origin "$BRANCH" 2>&1
git checkout "$BRANCH" 2>&1
git reset --hard "origin/$BRANCH" 2>&1
echo "Current commit: $(git log --oneline -1)"

# ============================================================
# STEP 3: COPY EA + CONFIG FILES
# ============================================================
echo ""
echo ">>> STEP 3: Copying files..."
mkdir -p "$EA_DIR" "$CFG_DIR"
cp -v EA/*.mq5 EA/*.mqh "$EA_DIR/" 2>&1
cp -v configs/*.json "$CFG_DIR/" 2>&1
echo "Files copied: OK"

# ============================================================
# STEP 4: DELETE OLD .ex5 + COMPILE
# ============================================================
echo ""
echo ">>> STEP 4: Compiling EA..."

# Delete old compiled file to force fresh compile
rm -f "${EA_DIR}/PropFirmBot.ex5"
echo "Old .ex5 deleted"

# Ensure Xvfb is running (MetaEditor needs display)
if ! pgrep Xvfb > /dev/null; then
    echo "Starting Xvfb..."
    nohup Xvfb :99 -screen 0 1280x1024x24 >/dev/null 2>&1 &
    sleep 2
fi

# Compile with MetaEditor
cd "$EA_DIR"
wine "${MT5}/metaeditor64.exe" /compile:PropFirmBot.mq5 /log 2>/dev/null
COMPILE_EXIT=$?
sleep 5

# ============================================================
# STEP 5: VERIFY COMPILATION (critical check!)
# ============================================================
echo ""
echo ">>> STEP 5: Verifying compilation..."

if [ -f "${EA_DIR}/PropFirmBot.ex5" ]; then
    EX5_SIZE=$(stat -c%s "${EA_DIR}/PropFirmBot.ex5" 2>/dev/null || echo "0")
    EX5_DATE=$(stat -c%y "${EA_DIR}/PropFirmBot.ex5" 2>/dev/null)
    echo "COMPILE SUCCESS!"
    echo "  File: PropFirmBot.ex5"
    echo "  Size: ${EX5_SIZE} bytes"
    echo "  Date: ${EX5_DATE}"

    if [ "$EX5_SIZE" -lt 1000 ]; then
        echo "WARNING: .ex5 file is suspiciously small!"
    fi
else
    echo "COMPILE FAILED - .ex5 not found!"
    echo "Checking MetaEditor log..."
    # MetaEditor logs are UTF-16LE
    LOGFILE="${EA_DIR}/PropFirmBot.log"
    if [ -f "$LOGFILE" ]; then
        iconv -f UTF-16LE -t UTF-8 "$LOGFILE" 2>/dev/null | tail -20
    fi
    echo ""
    echo "Trying alternative: check if old .ex5 exists elsewhere..."
    find "${MT5}" -name "PropFirmBot.ex5" -type f 2>/dev/null
fi

# ============================================================
# STEP 6: ENSURE DISPLAY SERVICES (Xvfb + VNC)
# ============================================================
echo ""
echo ">>> STEP 6: Display services..."

if ! pgrep Xvfb > /dev/null; then
    nohup Xvfb :99 -screen 0 1280x1024x24 >/dev/null 2>&1 &
    sleep 1
fi
echo "Xvfb: $(pgrep Xvfb > /dev/null && echo 'RUNNING' || echo 'NOT RUNNING')"

if ! pgrep x11vnc > /dev/null; then
    nohup x11vnc -display :99 -forever -shared -rfbport 5900 -nopw >/dev/null 2>&1 &
    sleep 1
fi
echo "VNC: $(pgrep x11vnc > /dev/null && echo 'RUNNING on :5900' || echo 'NOT RUNNING')"

# ============================================================
# STEP 7: START MT5 (nohup + setsid = fully detached from SSH)
# ============================================================
echo ""
echo ">>> STEP 7: Starting MT5..."

nohup setsid wine "${MT5}/terminal64.exe" /portable >/dev/null 2>&1 &
disown -a
sleep 8

# ============================================================
# STEP 8: VERIFY MT5 IS RUNNING
# ============================================================
echo ""
echo ">>> STEP 8: Verifying MT5..."

MT5_PID=$(pgrep -f terminal64.exe)
if [ -n "$MT5_PID" ]; then
    echo "MT5 RUNNING - PID: $MT5_PID"
else
    echo "MT5 NOT RUNNING - retrying..."
    nohup setsid wine "${MT5}/terminal64.exe" /portable >/dev/null 2>&1 &
    disown -a
    sleep 10
    MT5_PID=$(pgrep -f terminal64.exe)
    if [ -n "$MT5_PID" ]; then
        echo "MT5 RUNNING (2nd attempt) - PID: $MT5_PID"
    else
        echo "MT5 FAILED TO START!"
    fi
fi

# ============================================================
# STEP 9: INSTALL WATCHDOG (auto-restart if MT5 crashes)
# ============================================================
echo ""
echo ">>> STEP 9: Installing watchdog..."

# Create watchdog script
cat > /root/mt5_watchdog.sh << 'WATCHDOG'
#!/bin/bash
# MT5 Watchdog - auto-restart if crashed
export DISPLAY=:99
export WINEPREFIX=/root/.wine
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
LOGFILE="/root/mt5_watchdog.log"
TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"

# Ensure Xvfb running
pgrep Xvfb > /dev/null || (nohup Xvfb :99 -screen 0 1280x1024x24 >/dev/null 2>&1 &)

# Check if MT5 is running
if ! pgrep -f terminal64.exe > /dev/null; then
    TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M UTC')
    echo "${TIMESTAMP} - MT5 crashed! Restarting..." >> "$LOGFILE"

    # Start MT5
    nohup setsid wine "${MT5}/terminal64.exe" /portable >/dev/null 2>&1 &
    disown -a
    sleep 8

    # Verify
    if pgrep -f terminal64.exe > /dev/null; then
        echo "${TIMESTAMP} - MT5 restarted successfully" >> "$LOGFILE"
        MSG="🔄 MT5 Watchdog: Bot crashed and was auto-restarted at ${TIMESTAMP}"
    else
        echo "${TIMESTAMP} - MT5 restart FAILED" >> "$LOGFILE"
        MSG="🚨 MT5 Watchdog: Bot crashed and restart FAILED at ${TIMESTAMP}"
    fi

    # Send Telegram alert
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="${MSG}" > /dev/null 2>&1
fi

# Also ensure VNC is running
pgrep x11vnc > /dev/null || nohup x11vnc -display :99 -forever -shared -rfbport 5900 -nopw >/dev/null 2>&1 &
WATCHDOG

chmod +x /root/mt5_watchdog.sh

# Install cron job - runs every 2 minutes
CRON_LINE="*/2 * * * * /root/mt5_watchdog.sh"
(crontab -l 2>/dev/null | grep -v "mt5_watchdog" ; echo "$CRON_LINE") | crontab -
echo "Watchdog installed: runs every 2 minutes"
echo "Cron entry: $(crontab -l 2>/dev/null | grep mt5_watchdog)"

# ============================================================
# FINAL STATUS
# ============================================================
echo ""
echo "=========================================="
echo "  DEPLOY SUMMARY - $(date -u)"
echo "=========================================="
echo "Repo branch: $BRANCH"
echo "Commit: $(cd $REPO && git log --oneline -1)"
echo "EA .ex5: $([ -f '${EA_DIR}/PropFirmBot.ex5' ] && echo 'EXISTS' || echo 'MISSING')"
echo "MT5: $(pgrep -f terminal64.exe > /dev/null && echo 'RUNNING' || echo 'NOT RUNNING')"
echo "Xvfb: $(pgrep Xvfb > /dev/null && echo 'RUNNING' || echo 'NOT RUNNING')"
echo "VNC: $(pgrep x11vnc > /dev/null && echo 'RUNNING' || echo 'NOT RUNNING')"
echo "Watchdog: $(crontab -l 2>/dev/null | grep -q mt5_watchdog && echo 'INSTALLED' || echo 'NOT INSTALLED')"
echo "=========================================="
echo "DEPLOY COMPLETE"
echo "=========================================="
