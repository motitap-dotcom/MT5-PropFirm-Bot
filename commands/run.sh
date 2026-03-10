#!/bin/bash
# ============================================================
# STEP 1: Recompile to ensure .ex5 exists for watchdog restarts
# STEP 2: Verify EA is running v4.0
# STEP 3: Confirm watchdog is active
# ============================================================
echo "=== VERIFY + FIX $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5}/MQL5/Experts/PropFirmBot"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# --- Check current state ---
echo ""
echo ">>> CURRENT STATE"
echo "MT5: $(pgrep -f terminal64.exe > /dev/null && echo 'RUNNING (PID: '$(pgrep -f terminal64.exe | head -1)')' || echo 'NOT RUNNING')"
echo "Account balance from last log:"
tail -50 "${MT5}/MQL5/Logs/$(date +%Y%m%d).log" 2>/dev/null | iconv -f UTF-16LE -t UTF-8 2>/dev/null | grep -i "heartbeat\|balance\|trade\|signal\|risk\|init\|error" | tail -15

# --- Check .ex5 status ---
echo ""
echo ">>> EX5 STATUS"
find "${MT5}/MQL5" -name "PropFirmBot.ex5" -type f -ls 2>/dev/null
EX5_EXISTS=$(find "${MT5}/MQL5" -name "PropFirmBot.ex5" -type f 2>/dev/null | head -1)

if [ -z "$EX5_EXISTS" ]; then
    echo ".ex5 MISSING - need to recompile"
    echo ""
    echo ">>> RECOMPILING (MT5 must be stopped first)..."

    # Stop MT5 to release file locks
    pkill -f terminal64.exe 2>/dev/null
    sleep 3
    pkill -9 -f terminal64.exe 2>/dev/null
    sleep 1

    # Compile from EA directory
    cd "${EA_DIR}"
    echo "Working dir: $(pwd)"
    echo "Source file: $(ls -la PropFirmBot.mq5 2>/dev/null)"

    # Run MetaEditor with extra wait time
    wine "${MT5}/metaeditor64.exe" /compile:"PropFirmBot.mq5" /log 2>/dev/null &
    COMPILE_PID=$!
    echo "MetaEditor PID: $COMPILE_PID"

    # Wait up to 30 seconds for compile
    for i in $(seq 1 30); do
        sleep 1
        if ! kill -0 $COMPILE_PID 2>/dev/null; then
            echo "MetaEditor finished after ${i}s"
            break
        fi
    done
    kill $COMPILE_PID 2>/dev/null

    # Check result everywhere
    echo ""
    echo "Searching for .ex5..."
    find /root/.wine -name "PropFirmBot.ex5" -type f -ls 2>/dev/null

    # Check the MetaEditor log
    echo ""
    echo "MetaEditor log:"
    if [ -f "${MT5}/logs/metaeditor.log" ]; then
        tail -5 "${MT5}/logs/metaeditor.log" 2>/dev/null
    fi

    # Read compilation log
    if [ -f "${EA_DIR}/PropFirmBot.log" ]; then
        echo "Compile log:"
        iconv -f UTF-16LE -t UTF-8 "${EA_DIR}/PropFirmBot.log" 2>/dev/null | grep -i "error\|warning\|result"
    fi

    # Start MT5 again
    echo ""
    echo ">>> Restarting MT5..."
    pgrep Xvfb > /dev/null || (nohup Xvfb :99 -screen 0 1280x1024x24 >/dev/null 2>&1 & sleep 1)
    pgrep x11vnc > /dev/null || nohup x11vnc -display :99 -forever -shared -rfbport 5900 -nopw >/dev/null 2>&1 &
    nohup setsid wine "${MT5}/terminal64.exe" /portable >/dev/null 2>&1 &
    disown -a
    sleep 10
    echo "MT5: $(pgrep -f terminal64.exe > /dev/null && echo 'RUNNING' || echo 'NOT RUNNING')"
else
    echo ".ex5 EXISTS: $EX5_EXISTS"
    echo "Size: $(stat -c%s "$EX5_EXISTS") bytes"
    echo "Date: $(stat -c%y "$EX5_EXISTS")"
fi

# --- Verify EA is loaded and running ---
echo ""
echo ">>> EA ACTIVITY (last 20 log lines)"
sleep 5
tail -100 "${MT5}/MQL5/Logs/$(date +%Y%m%d).log" 2>/dev/null | iconv -f UTF-16LE -t UTF-8 2>/dev/null | grep -i "propfirm\|heartbeat\|signal\|trade\|error\|init\|guardian\|risk\|newbar" | tail -20

# --- Watchdog status ---
echo ""
echo ">>> WATCHDOG STATUS"
crontab -l 2>/dev/null | grep mt5_watchdog
echo "Watchdog log:"
tail -5 /root/mt5_watchdog.log 2>/dev/null || echo "(no log yet - watchdog hasn't needed to restart)"

# --- Final summary ---
echo ""
echo "=========================================="
echo "  FINAL STATUS $(date -u)"
echo "=========================================="
echo "MT5: $(pgrep -f terminal64.exe > /dev/null && echo 'RUNNING (PID: '$(pgrep -f terminal64.exe | head -1)')' || echo 'NOT RUNNING')"
echo "EA .ex5: $(find "${MT5}/MQL5" -name "PropFirmBot.ex5" -type f 2>/dev/null | head -1 || echo 'MISSING')"
echo "Xvfb: $(pgrep Xvfb > /dev/null && echo 'RUNNING' || echo 'NOT RUNNING')"
echo "VNC: $(pgrep x11vnc > /dev/null && echo 'RUNNING' || echo 'NOT RUNNING')"
echo "Watchdog: $(crontab -l 2>/dev/null | grep -q mt5_watchdog && echo 'ACTIVE (every 2 min)' || echo 'NOT SET')"
echo "=========================================="
