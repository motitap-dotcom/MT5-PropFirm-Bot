#!/bin/bash
###############################################
# FIX & START MT5 - Full automated script
# Run on VPS: bash /root/MT5-PropFirm-Bot/scripts/fix_and_start.sh
###############################################

echo "=== STEP 1: Kill all Wine processes ==="
wineserver -k 2>/dev/null
pkill -f wine 2>/dev/null
pkill -f terminal64 2>/dev/null
sleep 3
echo "Done - all Wine processes killed"

echo ""
echo "=== STEP 2: Ensure VNC is running ==="
if pgrep Xvfb > /dev/null; then
    echo "Xvfb already running"
else
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
    echo "Xvfb started"
fi

if pgrep x11vnc > /dev/null; then
    echo "x11vnc already running"
else
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    sleep 1
    echo "x11vnc started"
fi
export DISPLAY=:99

echo ""
echo "=== STEP 3: Disable Wine Mono dialog ==="
wine reg add "HKCU\\Software\\Wine\\DllOverrides" /v mscoree /d "" /f 2>/dev/null
sleep 2
echo "Done - Mono dialog disabled"

echo ""
echo "=== STEP 4: Update EA files from repo ==="
cd /root/MT5-PropFirm-Bot
git pull origin claude/build-cfd-trading-bot-fl0ld 2>/dev/null
EA_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot"
mkdir -p "$EA_DIR"
cp EA/*.mq5 EA/*.mqh "$EA_DIR/"
echo "EA files copied"

echo ""
echo "=== STEP 5: Compile EA ==="
cd "/root/.wine/drive_c/Program Files/MetaTrader 5"
wine metaeditor64.exe /compile:MQL5/Experts/PropFirmBot/PropFirmBot.mq5 /log 2>/dev/null
sleep 5

# Check compilation result
if grep -q "0 errors" MQL5/Experts/PropFirmBot/PropFirmBot.log 2>/dev/null; then
    echo "Compilation SUCCESS - 0 errors"
else
    echo "Compilation RESULT:"
    tail -3 MQL5/Experts/PropFirmBot/PropFirmBot.log 2>/dev/null
fi

# Verify .ex5 exists
if [ -f "MQL5/Experts/PropFirmBot/PropFirmBot.ex5" ]; then
    echo "PropFirmBot.ex5 exists ($(stat -c%s "MQL5/Experts/PropFirmBot/PropFirmBot.ex5") bytes)"
else
    echo "ERROR: PropFirmBot.ex5 NOT FOUND"
    exit 1
fi

echo ""
echo "=== STEP 6: Start MT5 ==="
wineserver -k 2>/dev/null
sleep 2
DISPLAY=:99 nohup wine "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" >/dev/null 2>&1 &
echo "Waiting 15 seconds for MT5 to start..."
sleep 15

if pgrep -a terminal64 > /dev/null; then
    echo ""
    echo "==========================================="
    echo "  MT5 IS RUNNING"
    echo "==========================================="
    echo ""
    echo "Now connect with VNC to 77.237.234.2:5900"
    echo "Then:"
    echo "  1. Login to FundedNext account if needed"
    echo "  2. Open EURUSD M15 chart"
    echo "  3. Drag PropFirmBot EA onto chart"
    echo "  4. Enable AutoTrading (green button)"
    echo ""
else
    echo ""
    echo "MT5 did not start. Trying alternative method..."
    # Try with explicit wineprefix
    WINEPREFIX=/root/.wine DISPLAY=:99 nohup wine "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" >/dev/null 2>&1 &
    sleep 15
    if pgrep -a terminal64 > /dev/null; then
        echo "==========================================="
        echo "  MT5 IS RUNNING (alternative method)"
        echo "==========================================="
    else
        echo "==========================================="
        echo "  MT5 FAILED TO START"
        echo "  Check VNC - there may be a dialog box"
        echo "==========================================="
    fi
fi
