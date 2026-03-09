#!/bin/bash
# =============================================================
# MT5 Complete Fix + Auto-Restart Watchdog Setup
# This script does EVERYTHING:
#   1. Fixes DNS & time
#   2. Ensures display (Xvfb + VNC)
#   3. Restarts MT5 with proper config
#   4. Creates watchdog script (auto-restart every 2 min)
#   5. Creates systemd services (survive reboot)
#   6. Creates boot startup script
#   7. Verifies everything works
#   8. Sends Telegram confirmation
# =============================================================

set -o pipefail
LOGFILE="/var/log/mt5_setup.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "============================================================"
echo "  MT5 COMPLETE FIX + AUTO-RESTART SETUP"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================================"
echo ""

# ---- Variables ----
MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
MT5_EXE="$MT5_DIR/terminal64.exe"
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"
CONFIG_DIR="$MT5_DIR/MQL5/Files/PropFirmBot"
DISPLAY_NUM=":99"
TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
ACCOUNT="11797849"
PASSWORD="gazDE62##"
SERVER="FundedNext-Server"

send_telegram() {
    local msg="$1"
    curl -s -4 --connect-timeout 10 --max-time 15 \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${msg}" \
        -d "parse_mode=HTML" > /dev/null 2>&1 || true
}

# ============================================================
# STEP 1: Fix DNS & Time
# ============================================================
echo "=== [1/8] Fix DNS & Time ==="

# Stable DNS
cat > /etc/resolv.conf << 'DNSEOF'
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 8.8.4.4
DNSEOF

# Prevent resolv.conf from being overwritten
chattr +i /etc/resolv.conf 2>/dev/null || true

# Sync time
ntpdate -u pool.ntp.org > /dev/null 2>&1 || timedatectl set-ntp true 2>/dev/null || true
echo "DNS: OK | Time: $(date '+%H:%M:%S UTC')"
echo ""

# ============================================================
# STEP 2: Ensure Display (Xvfb + x11vnc)
# ============================================================
echo "=== [2/8] Display Setup ==="

# Kill stale display processes if they're zombie
if pgrep -x Xvfb > /dev/null 2>&1; then
    # Check if Xvfb is actually responding
    if ! xdpyinfo -display $DISPLAY_NUM > /dev/null 2>&1; then
        echo "Xvfb is zombie - killing..."
        pkill -9 -x Xvfb 2>/dev/null
        sleep 2
    fi
fi

# Start Xvfb if needed
if ! pgrep -x Xvfb > /dev/null 2>&1; then
    echo "Starting Xvfb..."
    Xvfb $DISPLAY_NUM -screen 0 1280x1024x24 -ac +extension GLX +render -noreset &
    sleep 3
fi
export DISPLAY=$DISPLAY_NUM

# Start x11vnc if needed
if ! pgrep -x x11vnc > /dev/null 2>&1; then
    echo "Starting x11vnc..."
    x11vnc -display $DISPLAY_NUM -forever -shared -rfbport 5900 -bg -nopw -xkb 2>/dev/null
    sleep 1
fi

# Verify display
if xdpyinfo -display $DISPLAY_NUM > /dev/null 2>&1; then
    echo "Display: OK ($DISPLAY_NUM)"
else
    echo "Display: FAILED - trying again..."
    pkill -9 -x Xvfb 2>/dev/null
    sleep 2
    Xvfb $DISPLAY_NUM -screen 0 1280x1024x24 &
    sleep 3
fi

echo "VNC: $(pgrep -x x11vnc > /dev/null && echo 'OK (port 5900)' || echo 'FAILED')"
echo ""

# ============================================================
# STEP 3: Stop MT5 Cleanly
# ============================================================
echo "=== [3/8] Stop MT5 ==="

if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "Stopping MT5 gracefully..."
    pkill -f terminal64 2>/dev/null
    sleep 5
    # Force kill if still running
    if pgrep -f terminal64 > /dev/null 2>&1; then
        echo "Force killing MT5..."
        pkill -9 -f terminal64 2>/dev/null
        sleep 3
    fi
fi

# Clean Wine state
wineserver -k 2>/dev/null || true
sleep 2
rm -rf /tmp/.wine-* /tmp/wine-* 2>/dev/null || true

echo "MT5: STOPPED"
echo ""

# ============================================================
# STEP 4: Configure MT5 & Start
# ============================================================
echo "=== [4/8] Configure & Start MT5 ==="

# Write MT5 config
mkdir -p "$MT5_DIR/config" 2>/dev/null
cat > "$MT5_DIR/config/common.ini" << EOF
[Common]
Login=${ACCOUNT}
ProxyEnable=0
CertInstall=0
NewsEnable=0
[StartUp]
Expert=PropFirmBot\\PropFirmBot
ExpertParameters=
Symbol=EURUSD
Period=M15
[Experts]
AllowLiveTrading=1
AllowDllImport=0
Enabled=1
Account=${ACCOUNT}
Profile=0
EOF
echo "Config: Written"

# Start MT5
export DISPLAY=$DISPLAY_NUM
export WINEPREFIX=/root/.wine

cd "$MT5_DIR"
nohup wine "$MT5_EXE" /portable /login:${ACCOUNT} /password:${PASSWORD} /server:${SERVER} > /tmp/mt5_wine.log 2>&1 &
MT5_PID=$!
disown
echo "MT5 PID: $MT5_PID"

# Wait for MT5 to fully load
echo "Waiting for MT5 to load (30 seconds)..."
sleep 30

if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "MT5: RUNNING"
else
    echo "MT5: Still loading, waiting 30 more seconds..."
    sleep 30
    pgrep -af terminal64 2>&1 || echo "MT5: WARNING - may not have started"
fi
echo ""

# ============================================================
# STEP 5: Create Watchdog Script
# ============================================================
echo "=== [5/8] Creating Watchdog Script ==="

cat > /root/mt5_watchdog.sh << 'WATCHDOG_EOF'
#!/bin/bash
# =============================================================
# MT5 Watchdog - Checks every 2 minutes via cron
# If MT5 is down: restarts it + sends Telegram alert
# If display is down: restarts it too
# =============================================================

LOG="/var/log/mt5_watchdog.log"
MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
MT5_EXE="$MT5_DIR/terminal64.exe"
DISPLAY_NUM=":99"
TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
ACCOUNT="11797849"
PASSWORD="gazDE62##"
SERVER="FundedNext-Server"
LOCKFILE="/tmp/mt5_watchdog.lock"

# Prevent concurrent runs
if [ -f "$LOCKFILE" ]; then
    LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCKFILE" 2>/dev/null || echo 0) ))
    if [ "$LOCK_AGE" -lt 120 ]; then
        exit 0
    fi
    # Stale lock - remove it
    rm -f "$LOCKFILE"
fi
echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG"
}

send_telegram() {
    local msg="$1"
    curl -s -4 --connect-timeout 10 --max-time 15 \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${msg}" \
        -d "parse_mode=HTML" > /dev/null 2>&1 || true
}

RESTART_NEEDED=false
ISSUES=""

# --- Check 1: Xvfb ---
if ! pgrep -x Xvfb > /dev/null 2>&1; then
    log_msg "WATCHDOG: Xvfb down - restarting"
    ISSUES="${ISSUES}Xvfb down, "
    Xvfb $DISPLAY_NUM -screen 0 1280x1024x24 -ac +extension GLX +render -noreset &
    sleep 3
fi
export DISPLAY=$DISPLAY_NUM

# --- Check 2: x11vnc ---
if ! pgrep -x x11vnc > /dev/null 2>&1; then
    log_msg "WATCHDOG: x11vnc down - restarting"
    ISSUES="${ISSUES}VNC down, "
    x11vnc -display $DISPLAY_NUM -forever -shared -rfbport 5900 -bg -nopw -xkb 2>/dev/null
    sleep 1
fi

# --- Check 3: MT5 ---
if ! pgrep -f terminal64 > /dev/null 2>&1; then
    log_msg "WATCHDOG: MT5 DOWN - RESTARTING"
    RESTART_NEEDED=true
    ISSUES="${ISSUES}MT5 down"

    # Clean Wine state
    wineserver -k 2>/dev/null || true
    sleep 2
    rm -rf /tmp/.wine-* /tmp/wine-* 2>/dev/null || true

    # Start MT5
    export WINEPREFIX=/root/.wine
    cd "$MT5_DIR"
    nohup wine "$MT5_EXE" /portable /login:${ACCOUNT} /password:${PASSWORD} /server:${SERVER} > /tmp/mt5_wine.log 2>&1 &
    disown

    # Wait for startup
    sleep 30

    if pgrep -f terminal64 > /dev/null 2>&1; then
        log_msg "WATCHDOG: MT5 restarted successfully!"
        send_telegram "⚠️ <b>MT5 Watchdog Alert</b>
🔄 MT5 נפל והופעל מחדש אוטומטית
⏰ $(date '+%Y-%m-%d %H:%M:%S UTC')
📋 Issues: ${ISSUES}
✅ Status: MT5 RUNNING"
    else
        log_msg "WATCHDOG: CRITICAL - MT5 failed to restart!"

        # Second attempt with delay
        sleep 15
        nohup wine "$MT5_EXE" /portable /login:${ACCOUNT} /password:${PASSWORD} /server:${SERVER} > /tmp/mt5_wine.log 2>&1 &
        disown
        sleep 30

        if pgrep -f terminal64 > /dev/null 2>&1; then
            log_msg "WATCHDOG: MT5 restarted on second attempt"
            send_telegram "⚠️ <b>MT5 Watchdog Alert</b>
🔄 MT5 נפל - הופעל מחדש בניסיון שני
⏰ $(date '+%Y-%m-%d %H:%M:%S UTC')
✅ Status: MT5 RUNNING"
        else
            log_msg "WATCHDOG: CRITICAL - MT5 FAILED after 2 attempts!"
            send_telegram "🔴 <b>MT5 CRITICAL</b>
❌ MT5 נפל ולא הצליח לעלות אחרי 2 ניסיונות!
⏰ $(date '+%Y-%m-%d %H:%M:%S UTC')
⚠️ נדרשת בדיקה ידנית!
🔗 ssh root@77.237.234.2"
        fi
    fi
fi

# --- Check 4: Status Daemon ---
if ! pgrep -f mt5_status_daemon > /dev/null 2>&1; then
    log_msg "WATCHDOG: Status daemon down - restarting"
    if [ -f /root/MT5-PropFirm-Bot/scripts/mt5_status_daemon.py ]; then
        nohup python3 /root/MT5-PropFirm-Bot/scripts/mt5_status_daemon.py > /dev/null 2>&1 &
        disown
    fi
fi

# --- Periodic health log (every 30 min) ---
MINUTE=$(date +%M)
if [ "$MINUTE" = "00" ] || [ "$MINUTE" = "30" ]; then
    MT5_STATUS=$(pgrep -f terminal64 > /dev/null && echo "RUNNING" || echo "DOWN")
    XVFB_STATUS=$(pgrep -x Xvfb > /dev/null && echo "OK" || echo "DOWN")
    VNC_STATUS=$(pgrep -x x11vnc > /dev/null && echo "OK" || echo "DOWN")
    DAEMON_STATUS=$(pgrep -f mt5_status_daemon > /dev/null && echo "OK" || echo "DOWN")
    log_msg "HEALTH: MT5=${MT5_STATUS} Xvfb=${XVFB_STATUS} VNC=${VNC_STATUS} Daemon=${DAEMON_STATUS}"
fi

# --- Keep log manageable (max 2000 lines) ---
if [ -f "$LOG" ] && [ "$(wc -l < "$LOG")" -gt 2000 ]; then
    tail -1000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi
WATCHDOG_EOF

chmod +x /root/mt5_watchdog.sh
echo "Watchdog script: Created at /root/mt5_watchdog.sh"
echo ""

# ============================================================
# STEP 6: Create Boot Startup Script
# ============================================================
echo "=== [6/8] Creating Boot Startup Script ==="

cat > /root/mt5_startup.sh << 'STARTUP_EOF'
#!/bin/bash
# =============================================================
# MT5 Boot Startup Script
# Called by systemd on system boot
# Starts everything in the right order
# =============================================================

LOG="/var/log/mt5_startup.log"
echo "$(date '+%Y-%m-%d %H:%M:%S') - BOOT STARTUP BEGIN" >> "$LOG"

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
MT5_EXE="$MT5_DIR/terminal64.exe"
DISPLAY_NUM=":99"
TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
ACCOUNT="11797849"
PASSWORD="gazDE62##"
SERVER="FundedNext-Server"

# 1. Wait for network
echo "$(date '+%Y-%m-%d %H:%M:%S') - Waiting for network..." >> "$LOG"
for i in $(seq 1 30); do
    if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Network OK (attempt $i)" >> "$LOG"
        break
    fi
    sleep 2
done

# 2. Fix DNS
cat > /etc/resolv.conf << 'DNSEOF'
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 8.8.4.4
DNSEOF
chattr +i /etc/resolv.conf 2>/dev/null || true

# 3. Start Xvfb
if ! pgrep -x Xvfb > /dev/null 2>&1; then
    Xvfb $DISPLAY_NUM -screen 0 1280x1024x24 -ac +extension GLX +render -noreset &
    sleep 3
fi
export DISPLAY=$DISPLAY_NUM

# 4. Start x11vnc
if ! pgrep -x x11vnc > /dev/null 2>&1; then
    x11vnc -display $DISPLAY_NUM -forever -shared -rfbport 5900 -bg -nopw -xkb 2>/dev/null
    sleep 1
fi

# 5. Start MT5
export WINEPREFIX=/root/.wine
cd "$MT5_DIR"
nohup wine "$MT5_EXE" /portable /login:${ACCOUNT} /password:${PASSWORD} /server:${SERVER} > /tmp/mt5_wine.log 2>&1 &
disown

# 6. Start status daemon
if [ -f /root/MT5-PropFirm-Bot/scripts/mt5_status_daemon.py ]; then
    sleep 5
    nohup python3 /root/MT5-PropFirm-Bot/scripts/mt5_status_daemon.py > /dev/null 2>&1 &
    disown
fi

# 7. Wait and verify
sleep 45
MT5_OK=$(pgrep -f terminal64 > /dev/null && echo "RUNNING" || echo "FAILED")
echo "$(date '+%Y-%m-%d %H:%M:%S') - BOOT COMPLETE: MT5=$MT5_OK" >> "$LOG"

# 8. Telegram notification
curl -s -4 --connect-timeout 10 --max-time 15 \
    "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=🟢 <b>VPS Boot Complete</b>
🖥️ השרת עלה מחדש
📊 MT5: ${MT5_OK}
⏰ $(date '+%Y-%m-%d %H:%M:%S UTC')
🔄 Watchdog: Active (every 2 min)" \
    -d "parse_mode=HTML" > /dev/null 2>&1 || true
STARTUP_EOF

chmod +x /root/mt5_startup.sh
echo "Startup script: Created at /root/mt5_startup.sh"
echo ""

# ============================================================
# STEP 7: Install Systemd Services + Cron
# ============================================================
echo "=== [7/8] Installing Systemd Services + Cron ==="

# --- Service 1: MT5 Trading Bot (boot startup) ---
cat > /etc/systemd/system/mt5-trading.service << 'SVCEOF'
[Unit]
Description=MT5 Trading Bot - Auto Start
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User=root
ExecStart=/bin/bash /root/mt5_startup.sh
RemainAfterExit=yes
Restart=no

[Install]
WantedBy=multi-user.target
SVCEOF

# --- Service 2: MT5 Status Daemon ---
cat > /etc/systemd/system/mt5-status-daemon.service << 'SVCEOF2'
[Unit]
Description=MT5 Status JSON Daemon
After=network.target mt5-trading.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /root/MT5-PropFirm-Bot/scripts/mt5_status_daemon.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF2

# Enable services
systemctl daemon-reload
systemctl enable mt5-trading.service 2>&1 || true
systemctl enable mt5-status-daemon.service 2>&1 || true

# Start status daemon now
mkdir -p /var/bots
systemctl restart mt5-status-daemon.service 2>/dev/null || true
echo "Systemd services: Enabled"

# --- Cron: Watchdog every 2 minutes ---
# Remove old entries
crontab -l 2>/dev/null | grep -v "mt5_watchdog\|mt5_startup" > /tmp/cron_clean 2>/dev/null || true

# Add watchdog (every 2 min) + startup on reboot
cat >> /tmp/cron_clean << 'CRONEOF'
*/2 * * * * /bin/bash /root/mt5_watchdog.sh > /dev/null 2>&1
@reboot sleep 30 && /bin/bash /root/mt5_startup.sh > /dev/null 2>&1
CRONEOF

crontab /tmp/cron_clean
rm -f /tmp/cron_clean

echo "Cron jobs installed:"
crontab -l 2>&1
echo ""

# ============================================================
# STEP 8: Final Verification
# ============================================================
echo "=== [8/8] Final Verification ==="
echo ""

echo "--- Processes ---"
echo "  Xvfb:          $(pgrep -x Xvfb > /dev/null && echo '✅ RUNNING' || echo '❌ DOWN')"
echo "  x11vnc:        $(pgrep -x x11vnc > /dev/null && echo '✅ RUNNING (port 5900)' || echo '❌ DOWN')"
echo "  MT5:           $(pgrep -f terminal64 > /dev/null && echo '✅ RUNNING' || echo '⏳ LOADING...')"
echo "  Status Daemon: $(pgrep -f mt5_status_daemon > /dev/null && echo '✅ RUNNING' || echo '❌ DOWN')"
echo ""

echo "--- Auto-Restart Protection ---"
echo "  Watchdog cron:  $(crontab -l 2>/dev/null | grep -q mt5_watchdog && echo '✅ Every 2 minutes' || echo '❌ NOT SET')"
echo "  Boot service:   $(systemctl is-enabled mt5-trading.service 2>/dev/null || echo 'NOT SET')"
echo "  Reboot cron:    $(crontab -l 2>/dev/null | grep -q '@reboot.*mt5_startup' && echo '✅ Set' || echo '❌ NOT SET')"
echo "  Status daemon:  $(systemctl is-enabled mt5-status-daemon.service 2>/dev/null || echo 'NOT SET')"
echo ""

echo "--- Files ---"
echo "  Watchdog:  $(ls -la /root/mt5_watchdog.sh 2>/dev/null | awk '{print $5, $6, $7, $8, $9}' || echo 'MISSING')"
echo "  Startup:   $(ls -la /root/mt5_startup.sh 2>/dev/null | awk '{print $5, $6, $7, $8, $9}' || echo 'MISSING')"
echo "  Status:    $(ls -la /var/bots/mt5_status.json 2>/dev/null | awk '{print $5, $6, $7, $8, $9}' || echo 'MISSING')"
echo ""

# MT5 latest log
echo "--- MT5 Log (last 10 lines) ---"
LATEST_LOG=$(ls -t "$MT5_DIR/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "  File: $(basename "$LATEST_LOG")"
    cat "$LATEST_LOG" | tr -d '\0' | tail -10 | sed 's/^/  /'
else
    LATEST_LOG2=$(ls -t "$MT5_DIR/logs/"*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG2" ]; then
        echo "  File: $(basename "$LATEST_LOG2")"
        cat "$LATEST_LOG2" | tr -d '\0' | tail -10 | sed 's/^/  /'
    else
        echo "  No logs yet"
    fi
fi
echo ""

# Send Telegram summary
MT5_STATUS=$(pgrep -f terminal64 > /dev/null && echo "✅ RUNNING" || echo "⏳ LOADING")
send_telegram "🔧 <b>MT5 Full Setup Complete</b>

📊 MT5: ${MT5_STATUS}
🛡️ Watchdog: Active (every 2 min)
🔄 Boot auto-start: Enabled
📡 Status daemon: Running
🖥️ VNC: Port 5900

<b>Protection layers:</b>
1️⃣ Cron watchdog - checks every 2 min
2️⃣ Systemd service - starts on boot
3️⃣ @reboot cron - backup boot start
4️⃣ Telegram alerts on crash/restart

⏰ $(date '+%Y-%m-%d %H:%M:%S UTC')"

echo "============================================================"
echo "  SETUP COMPLETE!"
echo ""
echo "  Protection layers installed:"
echo "  1. Watchdog (cron every 2 min) - restarts MT5 if crashed"
echo "  2. Systemd service - auto-starts MT5 on reboot"
echo "  3. @reboot cron - backup startup on reboot"
echo "  4. Telegram alerts - notifies on crash/restart/boot"
echo "  5. Status daemon - updates /var/bots/mt5_status.json"
echo ""
echo "  If MT5 crashes → back up within 2 minutes"
echo "  If VPS reboots → MT5 starts automatically"
echo "  Every event → Telegram notification to Noa"
echo "============================================================"
