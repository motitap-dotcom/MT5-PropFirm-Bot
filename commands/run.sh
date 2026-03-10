#!/bin/bash
# ============================================================
# DIAGNOSTIC + DEPLOY v4.0 - finding the real compile method
# ============================================================
echo "=== DIAGNOSTIC DEPLOY $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5}/MQL5/Experts/PropFirmBot"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# Ensure display
pgrep Xvfb > /dev/null || (nohup Xvfb :99 -screen 0 1280x1024x24 >/dev/null 2>&1 & sleep 2)

# Stop MT5
echo "--- Stopping MT5 ---"
pkill -f terminal64.exe 2>/dev/null
sleep 2
pkill -9 -f terminal64.exe 2>/dev/null
sleep 1

# Clean ALL old .ex5 and logs
echo "--- Cleaning old files ---"
find "${MT5}" -name "PropFirmBot.ex5" -type f -exec rm -v {} \; 2>/dev/null
find "${MT5}" -name "PropFirmBot.log" -type f -exec rm -v {} \; 2>/dev/null
echo "Cleaned"

# Show what we have
echo ""
echo "--- Source files in EA dir ---"
ls -la "${EA_DIR}/"*.mq5 "${EA_DIR}/"*.mqh 2>/dev/null | head -5
echo "($(ls "${EA_DIR}/"*.mqh 2>/dev/null | wc -l) .mqh files total)"

# Try compile METHOD 1: from EA_DIR with just filename
echo ""
echo "=== METHOD 1: cd to EA_DIR, compile PropFirmBot.mq5 ==="
cd "${EA_DIR}"
wine "${MT5}/metaeditor64.exe" /compile:"PropFirmBot.mq5" /log 2>/dev/null
sleep 8
echo "Looking for .ex5..."
find "${MT5}/MQL5" -name "PropFirmBot.ex5" -type f -ls 2>/dev/null
FOUND1=$(find "${MT5}/MQL5" -name "PropFirmBot.ex5" -type f 2>/dev/null | head -1)

if [ -n "$FOUND1" ]; then
    echo "METHOD 1 WORKED! Found: $FOUND1"
    EX5_PATH="$FOUND1"
else
    echo "Method 1: no .ex5 found"

    # Show compilation log
    echo "--- Compilation log ---"
    for logf in $(find "${MT5}" -name "PropFirmBot.log" -newer "${EA_DIR}/PropFirmBot.mq5" 2>/dev/null); do
        echo "Log file: $logf ($(stat -c%y "$logf"))"
        iconv -f UTF-16LE -t UTF-8 "$logf" 2>/dev/null | grep -i "error\|warning\|result\|compil"
    done

    # Check if log is even new
    echo "--- All PropFirmBot.log files ---"
    find "${MT5}" -name "PropFirmBot.log" -type f -exec ls -la {} \; 2>/dev/null

    # Try compile METHOD 2: full Windows-style path
    echo ""
    echo "=== METHOD 2: Full path compile ==="
    cd /tmp
    WINPATH="C:\\\\Program Files\\\\MetaTrader 5\\\\MQL5\\\\Experts\\\\PropFirmBot\\\\PropFirmBot.mq5"
    wine "${MT5}/metaeditor64.exe" /compile:"${WINPATH}" /log 2>/dev/null
    sleep 8
    find "${MT5}/MQL5" -name "PropFirmBot.ex5" -type f -ls 2>/dev/null
    FOUND2=$(find "${MT5}/MQL5" -name "PropFirmBot.ex5" -type f 2>/dev/null | head -1)

    if [ -n "$FOUND2" ]; then
        echo "METHOD 2 WORKED! Found: $FOUND2"
        EX5_PATH="$FOUND2"
    else
        echo "Method 2: no .ex5 found"

        # Try compile METHOD 3: use MQL5/Experts as working dir
        echo ""
        echo "=== METHOD 3: cd to MQL5/Experts, compile PropFirmBot/PropFirmBot.mq5 ==="
        cd "${MT5}/MQL5/Experts"
        wine "${MT5}/metaeditor64.exe" /compile:"PropFirmBot\\PropFirmBot.mq5" /log 2>/dev/null
        sleep 8
        find "${MT5}/MQL5" -name "PropFirmBot.ex5" -type f -ls 2>/dev/null
        FOUND3=$(find "${MT5}/MQL5" -name "PropFirmBot.ex5" -type f 2>/dev/null | head -1)

        if [ -n "$FOUND3" ]; then
            echo "METHOD 3 WORKED! Found: $FOUND3"
            EX5_PATH="$FOUND3"
        else
            echo "Method 3: no .ex5 found"

            # Try METHOD 4: use Wine Z: drive path
            echo ""
            echo "=== METHOD 4: Wine Z: drive path ==="
            ZPATH="Z:${EA_DIR}/PropFirmBot.mq5"
            ZPATH_WIN=$(echo "$ZPATH" | sed 's|/|\\|g')
            echo "Path: $ZPATH_WIN"
            wine "${MT5}/metaeditor64.exe" /compile:"${ZPATH_WIN}" /log 2>/dev/null
            sleep 8
            find "${MT5}/MQL5" -name "PropFirmBot.ex5" -type f -ls 2>/dev/null
            FOUND4=$(find "${MT5}/MQL5" -name "PropFirmBot.ex5" -type f 2>/dev/null | head -1)

            if [ -n "$FOUND4" ]; then
                echo "METHOD 4 WORKED! Found: $FOUND4"
                EX5_PATH="$FOUND4"
            else
                echo "Method 4: no .ex5 found"
                echo ""
                echo "--- ALL logs found ---"
                find "${MT5}" -name "*.log" -newer "${EA_DIR}/PropFirmBot.mq5" -type f 2>/dev/null | while read f; do
                    echo "=== $f ==="
                    iconv -f UTF-16LE -t UTF-8 "$f" 2>/dev/null | tail -5
                done

                # Last resort: check ALL .ex5 files anywhere
                echo ""
                echo "--- ALL .ex5 files in Wine drive ---"
                find /root/.wine -name "*.ex5" -newer "${EA_DIR}/PropFirmBot.mq5" -type f -ls 2>/dev/null
            fi
        fi
    fi
fi

# Start MT5 regardless
echo ""
echo "=== Starting MT5 ==="
pgrep Xvfb > /dev/null || (nohup Xvfb :99 -screen 0 1280x1024x24 >/dev/null 2>&1 & sleep 1)
pgrep x11vnc > /dev/null || nohup x11vnc -display :99 -forever -shared -rfbport 5900 -nopw >/dev/null 2>&1 &
nohup setsid wine "${MT5}/terminal64.exe" /portable >/dev/null 2>&1 &
disown -a
sleep 8
echo "MT5: $(pgrep -f terminal64.exe > /dev/null && echo 'RUNNING (PID: '$(pgrep -f terminal64.exe | head -1)')' || echo 'NOT RUNNING')"

echo ""
echo "=== DONE $(date -u) ==="
