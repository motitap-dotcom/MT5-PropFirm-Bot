#!/bin/bash
# Fix: MetaEditor compiles OK but .ex5 doesn't persist on disk
# Solution: use wineserver --wait + sync to flush Wine filesystem
echo "=== COMPILE FIX $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5}/MQL5/Experts/PropFirmBot"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# Ensure display
pgrep Xvfb > /dev/null || (nohup Xvfb :99 -screen 0 1280x1024x24 >/dev/null 2>&1 & sleep 2)

# Stop MT5 so we can do clean compile cycle
echo ">>> Stopping MT5..."
pkill -f terminal64.exe 2>/dev/null
sleep 2
pkill -9 -f terminal64.exe 2>/dev/null
sleep 1

# Wait for wineserver to fully stop (flush pending writes)
echo ">>> Flushing Wine filesystem..."
wineserver -w 2>/dev/null
sync
sleep 2

# Delete old .ex5 and verify it's gone
rm -f "${EA_DIR}/PropFirmBot.ex5"
rm -f "${MT5}/MQL5/Experts/PropFirmBot.ex5"
sync
echo "Old .ex5 cleaned"

# Start MT5 first (MetaEditor needs Wine services)
echo ""
echo ">>> Starting MT5..."
nohup setsid wine "${MT5}/terminal64.exe" /portable >/dev/null 2>&1 &
disown -a
sleep 15
echo "MT5: $(pgrep -f terminal64.exe > /dev/null && echo 'RUNNING' || echo 'NOT RUNNING')"

# Compile - run MetaEditor and WAIT for it + flush
echo ""
echo ">>> Compiling EA..."
cd "${EA_DIR}"

# Run MetaEditor as foreground Wine process
wine "${MT5}/metaeditor64.exe" /compile:"PropFirmBot.mq5" /log 2>&1
COMPILE_RC=$?
echo "MetaEditor exit code: $COMPILE_RC"

# CRITICAL: Wait for Wine to flush file writes
echo ">>> Flushing Wine filesystem..."
wineserver -w 2>/dev/null
sync
sleep 3

# Check .ex5 in multiple places
echo ""
echo ">>> Searching for .ex5..."
find "${MT5}/MQL5" -name "PropFirmBot.ex5" -type f -ls 2>/dev/null
find /root/.wine -name "PropFirmBot.ex5" -type f -ls 2>/dev/null

# Also check if it's in Wine's dosdevices mapping
echo ""
echo ">>> Wine drive mappings:"
ls -la /root/.wine/dosdevices/ 2>/dev/null
echo ""
echo ">>> Checking C: drive link:"
readlink -f /root/.wine/dosdevices/c: 2>/dev/null

# Check if MetaEditor added new log entries
echo ""
echo ">>> MetaEditor log (latest):"
tail -6 "${MT5}/logs/metaeditor.log" 2>/dev/null

# Check PropFirmBot compile log
echo ""
echo ">>> Compile log:"
if [ -f "${EA_DIR}/PropFirmBot.log" ]; then
    iconv -f UTF-16LE -t UTF-8 "${EA_DIR}/PropFirmBot.log" 2>/dev/null | grep -i "result\|error\|warning\|generat"
else
    echo "No compile log in EA dir"
fi

# Alternative: check Wine's Z: drive (maps to /)
echo ""
echo ">>> Checking Z: drive for .ex5:"
find /root/.wine/dosdevices/ -name "PropFirmBot.ex5" 2>/dev/null

# Last resort: find ALL files modified in last 2 min
echo ""
echo ">>> Files modified in last 2 min in MQL5/Experts:"
find "${MT5}/MQL5/Experts" -type f -mmin -2 -ls 2>/dev/null

echo ""
echo ">>> Files modified in last 2 min anywhere in MT5:"
find "${MT5}" -type f -mmin -2 -name "*.ex5" -ls 2>/dev/null
find "${MT5}" -type f -mmin -2 -name "PropFirmBot*" -ls 2>/dev/null

# Restart MT5 (clean start)
echo ""
echo ">>> Restarting MT5..."
pkill -f terminal64.exe 2>/dev/null
sleep 2
wineserver -w 2>/dev/null
nohup setsid wine "${MT5}/terminal64.exe" /portable >/dev/null 2>&1 &
disown -a
sleep 10
echo "MT5: $(pgrep -f terminal64.exe > /dev/null && echo 'RUNNING (PID:'$(pgrep -f terminal64.exe | head -1)')' || echo 'NOT RUNNING')"

# Check EA loaded
echo ""
echo ">>> EA log:"
LOGFILE="${MT5}/MQL5/Logs/$(date +%Y%m%d).log"
if [ -f "$LOGFILE" ]; then
    iconv -f UTF-16LE -t UTF-8 "$LOGFILE" 2>/dev/null | grep -i "propfirm\|init\|heartbeat\|error" | tail -10
fi

echo ""
echo "=== DONE $(date -u) ==="
