#!/bin/bash
# CLEAN RESTART - kill ALL zombie Wine processes and start fresh MT5
echo "=== CLEAN RESTART $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# STEP 1: Kill EVERYTHING Wine-related
echo "--- 1. Kill ALL Wine processes ---"
echo "Before:"
ps aux | grep -E "wine|terminal64|start.exe|wineserver|winedevice" | grep -v grep | wc -l
ps aux | grep -E "wine|terminal64|start.exe|wineserver|winedevice" | grep -v grep

echo ""
echo "Killing all Wine processes..."

# Kill terminal64 first
pkill -f terminal64 2>/dev/null
sleep 2

# Kill all start.exe
pkill -f start.exe 2>/dev/null
sleep 1

# Kill all winedevice
pkill -f winedevice 2>/dev/null
sleep 1

# Kill ALL wineservers (the key fix!)
pkill -f wineserver 2>/dev/null
sleep 2

# Force kill anything remaining
pkill -9 -f "wine" 2>/dev/null
pkill -9 -f "terminal64" 2>/dev/null
pkill -9 -f "wineserver" 2>/dev/null
pkill -9 -f "winedevice" 2>/dev/null
pkill -9 -f "start.exe" 2>/dev/null
sleep 3

echo ""
echo "After cleanup:"
ps aux | grep -E "wine|terminal64|start.exe|wineserver|winedevice" | grep -v grep | wc -l
ps aux | grep -E "wine|terminal64|start.exe|wineserver|winedevice" | grep -v grep || echo "ALL CLEAN!"

# STEP 2: Clean Wine socket files
echo ""
echo "--- 2. Clean Wine sockets ---"
rm -rf /tmp/.wine-* 2>/dev/null
rm -rf /tmp/wine-* 2>/dev/null
echo "Wine temp files cleaned"

# STEP 3: Ensure display
echo ""
echo "--- 3. Display ---"
export DISPLAY=:99
if ! pgrep -x Xvfb > /dev/null 2>&1; then
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
fi
if ! pgrep -x x11vnc > /dev/null 2>&1; then
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    sleep 1
fi
echo "Display: OK"

# STEP 4: Start fresh MT5
echo ""
echo "--- 4. Start MT5 (clean) ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

cd "$MT5"
nohup wine terminal64.exe /login:11797849 /password:"gazDE62##" /server:FundedNext-Server > /tmp/mt5_wine_clean.log 2>&1 &
disown
echo "MT5 started (clean, PID: $!)"

# STEP 5: Wait for MT5 to initialize and connect
echo ""
echo "--- 5. Waiting 30 seconds for connection ---"
sleep 30

echo "MT5 running: $(pgrep -f terminal64 > /dev/null 2>&1 && echo YES || echo NO)"
echo ""
echo "Wine processes:"
ps aux | grep -E "wine|terminal64" | grep -v grep

echo ""
echo "Network connections from Wine/MT5:"
ss -tnp 2>/dev/null | grep -i "wine\|terminal" || echo "No wine connections in ss"
echo ""
echo "All outbound TCP connections (not SSH/VNC/DNS):"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -10

# STEP 6: Check terminal log
echo ""
echo "--- 6. Terminal log ---"
if [ -f "$MT5/logs/20260223.log" ]; then
    echo "Size: $(stat -c%s "$MT5/logs/20260223.log") bytes"
    cat "$MT5/logs/20260223.log" | tr -d '\0' | tail -20
fi

# STEP 7: Wait more and check for EA
echo ""
echo "--- 7. Wait 30 more seconds... ---"
sleep 30

echo "Terminal log after 60s:"
if [ -f "$MT5/logs/20260223.log" ]; then
    echo "Size: $(stat -c%s "$MT5/logs/20260223.log") bytes"
    cat "$MT5/logs/20260223.log" | tr -d '\0' | tail -20
fi

echo ""
echo "EA log:"
if [ -f "$MT5/MQL5/Logs/20260223.log" ]; then
    echo "EA LOG EXISTS!"
    cat "$MT5/MQL5/Logs/20260223.log" | tr -d '\0' | tail -30
else
    echo "No EA log yet"
fi

echo ""
echo "Outbound connections:"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -10

# STEP 8: Telegram
echo ""
echo "--- 8. Telegram ---"
curl -s -4 --connect-timeout 5 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
    -d "chat_id=7013213983" \
    -d "text=🔄 Clean restart done $(date '+%H:%M UTC')
MT5: $(pgrep -f terminal64 > /dev/null 2>&1 && echo 'RUNNING' || echo 'DOWN')
$(ss -tn state established 2>/dev/null | grep -v ':22 \|:5900 \|:53 ' | wc -l) outbound connections" > /dev/null 2>&1
echo "Sent"

echo ""
echo "=== DONE ==="
