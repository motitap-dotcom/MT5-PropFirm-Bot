#!/bin/bash
# Reinstall MT5 from FundedNext installer to restore server config
echo "=== REINSTALL MT5 $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

echo "--- 1. Backup EA files ---"
mkdir -p /tmp/ea_backup
cp -r "$MT5/MQL5/Experts/PropFirmBot/"* /tmp/ea_backup/ 2>/dev/null
echo "Backed up EA files: $(ls /tmp/ea_backup/ | wc -l) files"

echo ""
echo "--- 2. Kill MT5 ---"
pkill -f terminal64.exe 2>/dev/null; sleep 3
wineserver -k 2>/dev/null; sleep 3

echo ""
echo "--- 3. Download FundedNext MT5 installer ---"
if [ ! -f "/tmp/fn_mt5_setup.exe" ] || [ $(stat -c%s /tmp/fn_mt5_setup.exe 2>/dev/null || echo 0) -lt 1000000 ]; then
    echo "Downloading..."
    curl -L -o /tmp/fn_mt5_setup.exe "https://download.mql5.com/cdn/web/fundednext.ltd/mt5/fundednext5setup.exe" 2>/dev/null
fi
echo "Installer: $(stat -c%s /tmp/fn_mt5_setup.exe 2>/dev/null) bytes"

echo ""
echo "--- 4. Extract installer with 7z ---"
apt-get install -y -qq p7zip-full 2>/dev/null
mkdir -p /tmp/fn_extract
cd /tmp/fn_extract
7z x -y /tmp/fn_mt5_setup.exe > /dev/null 2>&1
echo "Extracted files:"
find /tmp/fn_extract -type f | head -30

echo ""
echo "--- 5. Look for server config files ---"
echo "Looking for server-related files..."
find /tmp/fn_extract -name "*.dat" -o -name "*.srv" -o -name "servers*" 2>/dev/null | head -10
echo ""
echo "Looking for FundedNext strings..."
grep -rl "FundedNext" /tmp/fn_extract/ 2>/dev/null | head -10
echo ""
echo "Looking for IP addresses in extracted files..."
find /tmp/fn_extract -type f -exec strings {} + 2>/dev/null | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | sort -u | head -20

echo ""
echo "--- 6. Try running installer with Wine (120s timeout) ---"
cd /tmp
wine fn_mt5_setup.exe /auto 2>/dev/null &
INST_PID=$!
echo "Installer PID: $INST_PID"

# Wait and check periodically
for i in 30 60 90 120; do
    sleep 30
    echo "  After ${i}s: servers/ has $(find "$MT5/config/servers" -type f 2>/dev/null | wc -l) files"
    if [ $(find "$MT5/config/servers" -type f 2>/dev/null | wc -l) -gt 0 ]; then
        echo "  SERVER CONFIG FOUND!"
        break
    fi
done

# Kill installer
kill $INST_PID 2>/dev/null
pkill -f fn_mt5_setup 2>/dev/null
sleep 5

echo ""
echo "--- 7. Check server config after install ---"
echo "config/servers/ contents:"
find "$MT5/config/servers" -type f 2>/dev/null
echo "Config/servers/ contents:"
find "$MT5/Config/servers" -type f 2>/dev/null
echo ""
echo "servers.dat sizes:"
stat -c "%n: %s bytes" "$MT5/config/servers.dat" "$MT5/Config/servers.dat" 2>/dev/null

echo ""
echo "--- 8. Restore EA files ---"
mkdir -p "$MT5/MQL5/Experts/PropFirmBot"
cp /tmp/ea_backup/* "$MT5/MQL5/Experts/PropFirmBot/" 2>/dev/null
echo "EA files restored: $(ls "$MT5/MQL5/Experts/PropFirmBot/" | wc -l) files"

echo ""
echo "--- 9. Start MT5 ---"
wineserver -k 2>/dev/null; sleep 3
cd "$MT5"
nohup wine terminal64.exe /login:11797849 /password:"gazDE62##" /server:FundedNext-Server </dev/null >/dev/null 2>&1 &
disown -a
echo "MT5 started, waiting 90s..."
sleep 90

echo ""
echo "--- 10. Final check ---"
echo "MT5: $(pgrep -f terminal64.exe > /dev/null 2>&1 && echo RUNNING || echo NOT_RUNNING)"
echo ""
echo "Terminal log (last 20):"
TLOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
[ -n "$TLOG" ] && cat "$TLOG" | tr -d '\0' | tail -20
echo ""
echo "Connections:"
ss -tn state established | grep -v ":22 \|:5900 \|:53 " | head -10
echo ""
echo "EA log:"
TODAY=$(date '+%Y%m%d')
EALOG="$MT5/MQL5/Logs/${TODAY}.log"
[ -f "$EALOG" ] && cat "$EALOG" | tr -d '\0' | tail -20 || echo "No EA log"

echo "=== DONE ==="
