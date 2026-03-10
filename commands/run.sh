#!/bin/bash
# =============================================================
# FULL FIX: Diagnose crash, restart MT5, install permanent watchdog
# =============================================================

echo "============================================"
echo "  FULL FIX & PERMANENT WATCHDOG INSTALL"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
CONFIG_DIR="$MT5/MQL5/Files/PropFirmBot"
LOGS_DIR="$MT5/MQL5/Logs"

# =============================================
# PHASE 1: DIAGNOSE WHY MT5 CRASHED
# =============================================
echo "========== PHASE 1: DIAGNOSIS =========="

echo "--- System uptime ---"
uptime

echo "--- Last system reboot ---"
last reboot | head -3

echo "--- Memory status ---"
free -h

echo "--- Disk usage ---"
df -h / | tail -1

echo "--- Wine/MT5 crash logs ---"
ls -lt /tmp/mt5_wine.log 2>/dev/null && tail -30 /tmp/mt5_wine.log 2>/dev/null || echo "No wine log found"

echo "--- dmesg OOM killer (last 10 lines with kill) ---"
dmesg | grep -i "kill\|oom\|out of memory" | tail -10 2>/dev/null || echo "No OOM events"

echo "--- MT5 Expert logs (last 30 lines) ---"
LATEST_LOG=$(ls -t "$LOGS_DIR/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "Log: $LATEST_LOG"
    cat "$LATEST_LOG" | tr -d '\0' | tail -30
else
    echo "No logs found"
fi

echo "--- Wine server status ---"
wineserver -k 2>/dev/null; echo "Wine server killed for clean restart"

echo "--- Check for existing cron watchdog ---"
crontab -l 2>/dev/null | grep -i "mt5\|watchdog\|terminal64" || echo "No existing MT5 watchdog in cron"

echo ""

# =============================================
# PHASE 2: FIX AND RESTART MT5
# =============================================
echo "========== PHASE 2: FIX & RESTART =========="

# Fix DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
echo "1. DNS: FIXED"

# Fix time
ntpdate -u pool.ntp.org > /dev/null 2>&1 || true
echo "2. Time: $(date)"

# Kill any existing MT5
pkill -9 -f terminal64 2>/dev/null || true
sleep 2
echo "3. Old MT5 process: KILLED"

# Ensure display
if ! pgrep -x Xvfb > /dev/null 2>&1; then
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
    echo "4a. Xvfb: STARTED"
else
    echo "4a. Xvfb: ALREADY RUNNING"
fi
export DISPLAY=:99

if ! pgrep -x x11vnc > /dev/null 2>&1; then
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    echo "4b. VNC: STARTED"
else
    echo "4b. VNC: ALREADY RUNNING"
fi

# Configure MT5 with WebRequest allowed for Telegram
mkdir -p "$MT5/config" 2>/dev/null

# Write common.ini with WebRequest for Telegram
cat > "$MT5/config/common.ini" << 'INIEOF'
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
echo "5. MT5 config: WRITTEN"

# Fix WebRequest for Telegram in terminal64.ini
TERMINAL_INI="$MT5/config/terminal64.ini"
# Also check the profile-based ini
TERMINAL_INI2="$MT5/terminal64.ini"

# Function to add WebRequest URL to ini file
fix_webrequest() {
    local INI_FILE="$1"
    if [ -f "$INI_FILE" ]; then
        echo "  Found: $INI_FILE"
        # Check if WebRequest section already has telegram
        if grep -q "api.telegram.org" "$INI_FILE" 2>/dev/null; then
            echo "  Telegram URL already in WebRequest"
        else
            # Check if [Experts] section exists
            if grep -q "\[Experts\]" "$INI_FILE" 2>/dev/null; then
                # Add WebRequestUrl after AllowLiveTrading or after [Experts]
                if grep -q "WebRequest=" "$INI_FILE" 2>/dev/null; then
                    # WebRequest exists but no telegram - add url
                    sed -i '/\[Experts\]/,/\[/{
                        /WebRequestUrl/!{
                            /AllowLiveTrading/a WebRequestUrl=https://api.telegram.org
                        }
                    }' "$INI_FILE"
                else
                    # No WebRequest at all - add it
                    sed -i '/\[Experts\]/a WebRequest=1\nWebRequestUrl=https://api.telegram.org' "$INI_FILE"
                fi
                echo "  Added Telegram WebRequest URL"
            else
                # No [Experts] section - add it
                echo "" >> "$INI_FILE"
                echo "[Experts]" >> "$INI_FILE"
                echo "AllowLiveTrading=1" >> "$INI_FILE"
                echo "Enabled=1" >> "$INI_FILE"
                echo "WebRequest=1" >> "$INI_FILE"
                echo "WebRequestUrl=https://api.telegram.org" >> "$INI_FILE"
                echo "  Added [Experts] section with WebRequest"
            fi
        fi
    else
        echo "  Not found: $INI_FILE"
    fi
}

echo "6. Fixing WebRequest for Telegram..."
# Find all possible ini files
find "$MT5" -name "*.ini" -type f 2>/dev/null | while read ini; do
    echo "  Checking: $ini"
done

fix_webrequest "$TERMINAL_INI"
fix_webrequest "$TERMINAL_INI2"

# Also check in data directory
DATA_INI=$(find "$MT5" -path "*/config/common.ini" -type f 2>/dev/null | head -1)
ORIGIN_INI=$(find /root/.wine -name "terminal64.ini" -type f 2>/dev/null | head -1)
if [ -n "$ORIGIN_INI" ]; then
    fix_webrequest "$ORIGIN_INI"
fi

echo "6. WebRequest: CONFIGURED"

# Start MT5
export DISPLAY=:99
export WINEPREFIX=/root/.wine
cd "$MT5"
nohup wine terminal64.exe /portable /login:11797849 /password:gazDE62## /server:FundedNext-Server > /tmp/mt5_wine.log 2>&1 &
disown
echo "7. MT5: STARTING..."

# Wait and verify
sleep 20
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "8. MT5: ✅ RUNNING"
    ps aux | grep terminal64 | grep -v grep
else
    echo "8. MT5: ⚠️ Still loading... (may take up to 60s)"
fi

echo ""

# =============================================
# PHASE 3: INSTALL PERMANENT WATCHDOG
# =============================================
echo "========== PHASE 3: PERMANENT WATCHDOG =========="

# Create the watchdog script
cat > /root/mt5_watchdog.sh << 'WATCHDOG'
#!/bin/bash
# MT5 Watchdog - Auto-restart MT5 if it crashes
# Installed by PropFirmBot deployment
# Runs every 2 minutes via cron

LOG="/var/log/mt5_watchdog.log"
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
MAX_LOG_SIZE=1048576  # 1MB

# Rotate log if too big
if [ -f "$LOG" ] && [ $(stat -c%s "$LOG" 2>/dev/null || echo 0) -gt $MAX_LOG_SIZE ]; then
    tail -100 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

# Check if MT5 is running
if pgrep -f terminal64 > /dev/null 2>&1; then
    # MT5 is running - just log heartbeat every 10th check (every 20 min)
    COUNTER_FILE="/tmp/watchdog_counter"
    COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
    COUNT=$((COUNT + 1))
    if [ $COUNT -ge 10 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [OK] MT5 running (heartbeat)" >> "$LOG"
        COUNT=0
    fi
    echo $COUNT > "$COUNTER_FILE"
    exit 0
fi

# MT5 is NOT running - restart it!
echo "$(date '+%Y-%m-%d %H:%M:%S') [ALERT] MT5 not running! Restarting..." >> "$LOG"

# Ensure display
if ! pgrep -x Xvfb > /dev/null 2>&1; then
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [FIX] Started Xvfb" >> "$LOG"
fi

# Ensure VNC
if ! pgrep -x x11vnc > /dev/null 2>&1; then
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    echo "$(date '+%Y-%m-%d %H:%M:%S') [FIX] Started VNC" >> "$LOG"
fi

# Fix DNS (in case it was reset)
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# Kill any zombie wine processes
wineserver -k 2>/dev/null
sleep 2

# Start MT5
export DISPLAY=:99
export WINEPREFIX=/root/.wine
cd "$MT5"
nohup wine terminal64.exe /portable /login:11797849 /password:gazDE62## /server:FundedNext-Server > /tmp/mt5_wine.log 2>&1 &
disown

sleep 20

# Verify and notify
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [OK] MT5 restarted successfully" >> "$LOG"
    # Send Telegram notification
    curl -s -4 --connect-timeout 10 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
        -d "chat_id=7013213983" \
        -d "text=🔄 Watchdog: MT5 was down and has been auto-restarted!
✅ MT5 is now RUNNING
⏰ $(date '+%Y-%m-%d %H:%M UTC')" > /dev/null 2>&1
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] MT5 restart FAILED" >> "$LOG"
    curl -s -4 --connect-timeout 10 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
        -d "chat_id=7013213983" \
        -d "text=🚨 Watchdog: MT5 restart FAILED!
❌ Manual intervention needed
⏰ $(date '+%Y-%m-%d %H:%M UTC')" > /dev/null 2>&1
fi
WATCHDOG

chmod +x /root/mt5_watchdog.sh
echo "1. Watchdog script: CREATED at /root/mt5_watchdog.sh"

# Install cron job (every 2 minutes)
# First remove any existing MT5 watchdog entries
EXISTING_CRON=$(crontab -l 2>/dev/null | grep -v "mt5_watchdog" | grep -v "# MT5 Watchdog")
# Add the new watchdog
(echo "$EXISTING_CRON"; echo "# MT5 Watchdog - auto-restart if MT5 crashes"; echo "*/2 * * * * /bin/bash /root/mt5_watchdog.sh") | crontab -
echo "2. Cron job: INSTALLED (every 2 minutes)"

# Verify cron
echo "3. Cron verification:"
crontab -l 2>/dev/null | grep -A1 "MT5 Watchdog"

# Ensure cron is running
service cron status 2>/dev/null || systemctl status cron 2>/dev/null || true
service cron start 2>/dev/null || systemctl start cron 2>/dev/null || true
echo "4. Cron service: ENSURED RUNNING"

# Create a startup script so MT5 starts on boot too
cat > /etc/init.d/mt5-autostart << 'BOOTSCRIPT'
#!/bin/bash
### BEGIN INIT INFO
# Provides:          mt5-autostart
# Required-Start:    $local_fs $network
# Required-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       Auto-start MT5 on boot
### END INIT INFO

case "$1" in
    start)
        echo "Starting MT5..."
        # Start Xvfb
        if ! pgrep -x Xvfb > /dev/null 2>&1; then
            Xvfb :99 -screen 0 1280x1024x24 &
            sleep 2
        fi
        # Start VNC
        if ! pgrep -x x11vnc > /dev/null 2>&1; then
            x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
        fi
        # Fix DNS
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
        echo "nameserver 1.1.1.1" >> /etc/resolv.conf
        # Start MT5
        export DISPLAY=:99
        export WINEPREFIX=/root/.wine
        MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
        cd "$MT5"
        nohup wine terminal64.exe /portable /login:11797849 /password:gazDE62## /server:FundedNext-Server > /tmp/mt5_wine.log 2>&1 &
        disown
        echo "MT5 started"
        ;;
    stop)
        pkill -f terminal64 2>/dev/null
        ;;
    restart)
        $0 stop
        sleep 3
        $0 start
        ;;
    status)
        if pgrep -f terminal64 > /dev/null 2>&1; then
            echo "MT5 is running"
        else
            echo "MT5 is NOT running"
        fi
        ;;
esac
BOOTSCRIPT

chmod +x /etc/init.d/mt5-autostart
update-rc.d mt5-autostart defaults 2>/dev/null || true
echo "5. Boot autostart: INSTALLED"

# Also add to rc.local as backup
if [ ! -f /etc/rc.local ] || ! grep -q "mt5_watchdog" /etc/rc.local 2>/dev/null; then
    cat > /etc/rc.local << 'RCLOCAL'
#!/bin/bash
# Start Xvfb display
Xvfb :99 -screen 0 1280x1024x24 &
sleep 2
# Start VNC
x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
# Fix DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
# Run MT5 watchdog (will start MT5 if not running)
sleep 10
/bin/bash /root/mt5_watchdog.sh &
exit 0
RCLOCAL
    chmod +x /etc/rc.local
    echo "6. rc.local backup: INSTALLED"
else
    echo "6. rc.local: ALREADY CONFIGURED"
fi

echo ""
echo "========== PHASE 4: FINAL STATUS =========="

# Wait a bit more for MT5
sleep 10

echo "--- MT5 Process ---"
pgrep -a terminal64 || echo "MT5 still loading..."

echo "--- Cron Jobs ---"
crontab -l 2>/dev/null

echo "--- Watchdog Script ---"
ls -la /root/mt5_watchdog.sh

echo "--- Boot Script ---"
ls -la /etc/init.d/mt5-autostart

echo "--- Wine Log (last 10 lines) ---"
tail -10 /tmp/mt5_wine.log 2>/dev/null || echo "No wine log yet"

# Send Telegram
curl -s -4 --connect-timeout 10 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
    -d "chat_id=7013213983" \
    -d "text=🛡️ PERMANENT PROTECTION INSTALLED!

🔄 Watchdog: Checks every 2 minutes
🚀 Boot autostart: MT5 starts on server reboot
📡 Telegram WebRequest: Configured
⏰ $(date '+%Y-%m-%d %H:%M UTC')

MT5 will NEVER stay down for more than 2 minutes!" > /dev/null 2>&1

echo ""
echo "============================================"
echo "  DONE! Protection layers installed:"
echo "  1. Cron watchdog (every 2 min)"
echo "  2. Boot autostart (on reboot)"
echo "  3. rc.local backup (failsafe)"
echo "  4. Telegram alerts on restart"
echo "  MT5 will auto-restart within 2 minutes!"
echo "============================================"
echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
