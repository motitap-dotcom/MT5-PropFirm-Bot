#!/bin/bash
# PropFirmBot - Fix Connection & Restart MT5
# Fixes: FundedNext login, time sync, DNS, restart MT5 with EA

echo "=== FIX SCRIPT START ==="
echo "Time: $(date '+%Y-%m-%d %H:%M:%S UTC')"

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"

# ============================================
# STEP 1: Fix DNS
# ============================================
echo ""
echo ">>> STEP 1: Fix DNS"
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
ping -c1 -W3 -4 google.com > /dev/null 2>&1 && echo "DNS: OK" || echo "DNS: FAILED"

# ============================================
# STEP 2: Fix system time via NTP
# ============================================
echo ""
echo ">>> STEP 2: Fix system time"
echo "Before: $(date)"
apt-get install -y -qq ntpdate > /dev/null 2>&1
ntpdate -u pool.ntp.org 2>&1 || ntpdate -u time.google.com 2>&1 || echo "NTP sync failed, trying timedatectl..."
timedatectl set-ntp true 2>/dev/null
echo "After: $(date)"

# ============================================
# STEP 3: Stop current MT5
# ============================================
echo ""
echo ">>> STEP 3: Stop MT5"
# Gracefully kill MT5
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "Killing MT5 process..."
    pkill -f terminal64
    sleep 3
    # Force kill if still running
    if pgrep -f terminal64 > /dev/null 2>&1; then
        pkill -9 -f terminal64
        sleep 2
    fi
    echo "MT5 stopped"
else
    echo "MT5 was not running"
fi

# Also kill any stuck wineserver
wineserver -k 2>/dev/null
sleep 2

# ============================================
# STEP 4: Ensure Xvfb and VNC are running
# ============================================
echo ""
echo ">>> STEP 4: Check display server"
if ! pgrep -x Xvfb > /dev/null 2>&1; then
    echo "Starting Xvfb..."
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
else
    echo "Xvfb already running"
fi
export DISPLAY=:99

if ! pgrep -x x11vnc > /dev/null 2>&1; then
    echo "Starting x11vnc..."
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    sleep 1
else
    echo "x11vnc already running"
fi

# ============================================
# STEP 5: Configure MT5 for auto-login
# ============================================
echo ""
echo ">>> STEP 5: Configure MT5 login"

# Create/update the MT5 startup config
# MT5 reads common.ini for startup settings
CONFIG_DIR="$MT5/config"
mkdir -p "$CONFIG_DIR" 2>/dev/null

# Write the server connection config
cat > "$CONFIG_DIR/common.ini" << 'INIEOF'
[Common]
Login=11797849
ProxyEnable=0
CertInstall=0
NewsEnable=0
[StartUp]
Expert=PropFirmBot\PropFirmBot
ExpertParameters=
Symbol=EURUSD
Period=M15
[Experts]
AllowLiveTrading=1
AllowDllImport=0
Enabled=1
Account=11797849
Profile=0
INIEOF

echo "common.ini updated"

# Also ensure the server file exists for FundedNext
SRV_DIR="$MT5/config/servers"
mkdir -p "$SRV_DIR" 2>/dev/null

# Write account credentials for auto-login
# MT5 uses .srv files but the simplest is to use command line args

# Add api.telegram.org to allowed URLs for WebRequest
# This is stored in the terminal's options
echo "Config files updated"

# ============================================
# STEP 6: Start MT5 with login parameters
# ============================================
echo ""
echo ">>> STEP 6: Start MT5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# Start MT5 with login credentials
cd "$MT5"
wine terminal64.exe /portable \
    /login:11797849 \
    /password:gazDE62## \
    /server:FundedNext-Server \
    &

MT5_PID=$!
echo "MT5 started with PID: $MT5_PID"

# Wait for MT5 to initialize
echo "Waiting 30 seconds for MT5 to connect..."
sleep 30

# Check if MT5 is running
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "MT5 is RUNNING"
    ps aux | grep terminal64 | grep -v grep
else
    echo "MT5 FAILED TO START!"
fi

# ============================================
# STEP 7: Check logs for connection
# ============================================
echo ""
echo ">>> STEP 7: Check connection status"

# Wait a bit more and check new logs
sleep 10

LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "Latest log: $(basename "$LATEST_LOG")"
    echo "Log size: $(stat -c%s "$LATEST_LOG") bytes"
    echo "--- Last 40 lines ---"
    cat "$LATEST_LOG" | tr -d '\0' | tail -40
else
    echo "No log files yet"
fi

# ============================================
# STEP 8: Send Telegram notification
# ============================================
echo ""
echo ">>> STEP 8: Telegram notification"
MT5_STATUS="UNKNOWN"
pgrep -f terminal64 > /dev/null 2>&1 && MT5_STATUS="RUNNING" || MT5_STATUS="DOWN"

curl -s -4 --connect-timeout 5 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
    -d "chat_id=7013213983" \
    -d "text=🔧 MT5 Restart Complete
Status: $MT5_STATUS
Time: $(date '+%H:%M:%S UTC')
Account: 11797849
Server: FundedNext-Server
Action: Auto-reconnect executed" 2>&1 | grep -o '"ok":[^,]*'

# ============================================
# STEP 9: Final status check
# ============================================
echo ""
echo ">>> STEP 9: Final status"
echo "MT5 Process:"
ps aux | grep terminal64 | grep -v grep || echo "NOT RUNNING"
echo ""
echo "Wine processes:"
ps aux | grep wine | grep -v grep
echo ""
echo "VNC:"
pgrep -la x11vnc || echo "VNC DOWN"
echo ""
echo "System time: $(date)"
echo ""

# Check if new log has any balance/connection info
sleep 5
LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "--- Updated log (last 20 lines) ---"
    cat "$LATEST_LOG" | tr -d '\0' | tail -20
fi

echo ""
echo "=== FIX SCRIPT DONE ==="
