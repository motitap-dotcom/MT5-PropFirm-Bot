#!/bin/bash
# Deploy updated EA with AutoTrading auto-fix + enable DLL imports
echo "=== DEPLOY EA UPDATE $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. Pull latest code
echo "[1] Pulling latest code..."
cd /root/MT5-PropFirm-Bot
git fetch origin claude/check-bot-update-status-KDu5H 2>&1
git checkout claude/check-bot-update-status-KDu5H 2>&1
git pull origin claude/check-bot-update-status-KDu5H 2>&1
echo ""

# 2. Copy EA files
echo "[2] Copying EA files..."
cp -v EA/*.mq5 "$EA_DIR/" 2>&1
cp -v EA/*.mqh "$EA_DIR/" 2>&1
echo ""

# 3. Enable DLL imports in startup.ini
echo "[3] Enabling DLL imports..."
SINI="$MT5/config/startup.ini"
if [ -f "$SINI" ]; then
    sed -i 's/AllowDllImport=0/AllowDllImport=1/' "$SINI"
    echo "startup.ini updated"
    cat "$SINI"
else
    echo "startup.ini not found!"
fi
echo ""

# 4. Also update common.ini
CINI="$MT5/config/common.ini"
if [ -f "$CINI" ]; then
    sed -i 's/AllowDllImport=0/AllowDllImport=1/' "$CINI"
    echo "common.ini updated"
fi

# 5. Update chart file to allow DLL
CHR="$MT5/profiles/charts/default/chart01.chr"
if [ -f "$CHR" ]; then
    # expertmode: bit 0=live trading, bit 1=DLL imports
    # Current: 33 = 32+1. Need: 35 = 32+2+1
    sed -i 's/expertmode=33/expertmode=35/' "$CHR"
    echo "Chart file: DLL imports enabled"
fi
echo ""

# 6. Stop MT5
echo "[6] Stopping MT5..."
pkill -f terminal64 2>/dev/null
sleep 3
pkill -9 -f terminal64 2>/dev/null
sleep 2

# 7. Compile EA
echo "[7] Compiling EA..."
COMPILER="$MT5/metaeditor64.exe"
if [ -f "$COMPILER" ]; then
    wine "$COMPILER" /compile:"$EA_DIR/PropFirmBot.mq5" /log 2>&1 | tail -5
    sleep 10
    # Check compilation result
    if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
        echo "Compilation SUCCESS - $(stat -c '%s bytes, %y' "$EA_DIR/PropFirmBot.ex5")"
    else
        echo "Compilation may have failed"
    fi
else
    echo "MetaEditor not found at $COMPILER"
    ls "$MT5/meta"* 2>/dev/null || echo "No metaeditor found"
fi
echo ""

# 8. Start MT5
echo "[8] Starting MT5..."
pgrep Xvfb || (Xvfb :99 -screen 0 1280x1024x24 & sleep 2)
nohup wine "$MT5/terminal64.exe" /portable /login:11797849 /server:FundedNext-Server /autotrading > /dev/null 2>&1 &
sleep 15

pgrep -f terminal64 > /dev/null && echo "MT5 RUNNING" || echo "MT5 NOT RUNNING"

# 9. Check EA log
echo "[9] EA log:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -15
echo ""

echo "=== DONE $(date -u) ==="
