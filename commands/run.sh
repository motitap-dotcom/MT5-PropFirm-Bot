#!/bin/bash
# =============================================================
# Fix MT5 + Setup Auto-Restart Watchdog
# =============================================================

echo "============================================"
echo "  MT5 Fix & Auto-Restart Setup"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_PATH="/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"
DISPLAY_NUM=":99"

# ---- Step 1: Check current state ----
echo "=== [1] Current State ==="
echo "MT5 process:"
pgrep -af terminal64 2>&1 || echo "  NOT RUNNING"
echo ""
echo "Xvfb process:"
pgrep -af Xvfb 2>&1 || echo "  NOT RUNNING"
echo ""
echo "x11vnc process:"
pgrep -af x11vnc 2>&1 || echo "  NOT RUNNING"
echo ""

# ---- Step 2: Ensure Xvfb is running ----
echo "=== [2] Ensuring Xvfb (virtual display) ==="
if ! pgrep -x Xvfb > /dev/null; then
    echo "Starting Xvfb..."
    Xvfb $DISPLAY_NUM -screen 0 1280x1024x24 &
    sleep 2
    echo "Xvfb started"
else
    echo "Xvfb already running"
fi
export DISPLAY=$DISPLAY_NUM
echo ""

# ---- Step 3: Ensure x11vnc is running ----
echo "=== [3] Ensuring VNC server ==="
if ! pgrep -x x11vnc > /dev/null; then
    echo "Starting x11vnc..."
    x11vnc -display $DISPLAY_NUM -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    sleep 1
    echo "x11vnc started"
else
    echo "x11vnc already running"
fi
echo ""

# ---- Step 4: Start MT5 ----
echo "=== [4] Starting MT5 ==="
if pgrep -f terminal64 > /dev/null; then
    echo "MT5 is already running - killing and restarting..."
    pkill -f terminal64
    sleep 3
fi

echo "Launching MT5..."
DISPLAY=$DISPLAY_NUM WINEPREFIX=/root/.wine wine "$MT5_PATH" &
sleep 5

if pgrep -f terminal64 > /dev/null; then
    echo "MT5 started successfully!"
else
    echo "WARNING: MT5 may not have started - checking again..."
    sleep 5
    pgrep -af terminal64 2>&1 || echo "MT5 FAILED TO START"
fi
echo ""

# ---- Step 5: Create Watchdog Script ----
echo "=== [5] Creating Watchdog Script ==="

cat > /root/mt5_watchdog.sh << 'WATCHDOG'
#!/bin/bash
# MT5 Watchdog - Auto-restart MT5 if it crashes
# Runs every 2 minutes via cron

LOG="/var/log/mt5_watchdog.log"
MT5_PATH="/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"
DISPLAY_NUM=":99"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG"
}

# Ensure Xvfb
if ! pgrep -x Xvfb > /dev/null; then
    log_msg "Xvfb not running - starting..."
    Xvfb $DISPLAY_NUM -screen 0 1280x1024x24 &
    sleep 2
    log_msg "Xvfb started"
fi

# Ensure x11vnc
if ! pgrep -x x11vnc > /dev/null; then
    log_msg "x11vnc not running - starting..."
    x11vnc -display $DISPLAY_NUM -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    sleep 1
    log_msg "x11vnc started"
fi

# Check MT5
if ! pgrep -f terminal64 > /dev/null; then
    log_msg "MT5 NOT RUNNING - restarting..."
    export DISPLAY=$DISPLAY_NUM
    WINEPREFIX=/root/.wine wine "$MT5_PATH" &
    sleep 10

    if pgrep -f terminal64 > /dev/null; then
        log_msg "MT5 restarted successfully!"

        # Send Telegram notification
        TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
        CHAT_ID="7013213983"
        MSG="⚠️ MT5 Watchdog: MT5 נפל והופעל מחדש אוטומטית! ($(date '+%H:%M:%S'))"
        curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
            -d chat_id="${CHAT_ID}" \
            -d text="${MSG}" \
            -d parse_mode="HTML" > /dev/null 2>&1
        log_msg "Telegram notification sent"
    else
        log_msg "CRITICAL: MT5 failed to restart!"

        TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
        CHAT_ID="7013213983"
        MSG="🔴 MT5 Watchdog: MT5 נפל ולא הצליח לעלות מחדש! נדרשת בדיקה ידנית!"
        curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
            -d chat_id="${CHAT_ID}" \
            -d text="${MSG}" \
            -d parse_mode="HTML" > /dev/null 2>&1
        log_msg "CRITICAL Telegram notification sent"
    fi
else
    # MT5 is running - all good (log only every 30 min to avoid huge logs)
    MINUTE=$(date +%M)
    if [ "$MINUTE" = "00" ] || [ "$MINUTE" = "30" ]; then
        log_msg "MT5 running OK"
    fi
fi

# Keep log file manageable (max 1000 lines)
if [ -f "$LOG" ] && [ $(wc -l < "$LOG") -gt 1000 ]; then
    tail -500 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi
WATCHDOG

chmod +x /root/mt5_watchdog.sh
echo "Watchdog script created at /root/mt5_watchdog.sh"
echo ""

# ---- Step 6: Setup Cron Job ----
echo "=== [6] Setting Up Cron (every 2 minutes) ==="

# Remove any existing mt5_watchdog cron entries
crontab -l 2>/dev/null | grep -v "mt5_watchdog" > /tmp/current_cron 2>/dev/null || true

# Add new cron entry
echo "*/2 * * * * /root/mt5_watchdog.sh" >> /tmp/current_cron

# Install new crontab
crontab /tmp/current_cron
rm -f /tmp/current_cron

echo "Cron job installed:"
crontab -l 2>&1
echo ""

# ---- Step 7: Also add to systemd for boot persistence ----
echo "=== [7] Creating Systemd Service (auto-start on boot) ==="

cat > /etc/systemd/system/mt5-trading.service << 'SERVICE'
[Unit]
Description=MT5 Trading Bot
After=network.target

[Service]
Type=forking
User=root
Environment=DISPLAY=:99
Environment=WINEPREFIX=/root/.wine
ExecStartPre=/bin/bash -c 'pgrep Xvfb || (Xvfb :99 -screen 0 1280x1024x24 & sleep 2)'
ExecStartPre=/bin/bash -c 'pgrep x11vnc || (x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null; sleep 1)'
ExecStart=/bin/bash -c 'wine "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" &'
ExecStop=/bin/bash -c 'pkill -f terminal64'
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable mt5-trading.service 2>&1
echo "Systemd service created and enabled (auto-start on reboot)"
echo ""

# ---- Step 8: Verify everything ----
echo "=== [8] Final Verification ==="
echo "MT5:"
pgrep -af terminal64 2>&1 || echo "  waiting for startup..."
echo ""
echo "Xvfb:"
pgrep -af Xvfb 2>&1 || echo "  NOT RUNNING"
echo ""
echo "x11vnc:"
pgrep -af x11vnc 2>&1 || echo "  NOT RUNNING"
echo ""
echo "Cron watchdog:"
crontab -l 2>/dev/null | grep mt5_watchdog || echo "  NOT SET"
echo ""
echo "Systemd service:"
systemctl is-enabled mt5-trading.service 2>&1
echo ""

echo "============================================"
echo "  SETUP COMPLETE!"
echo "  - MT5 restarted"
echo "  - Watchdog checks every 2 minutes"
echo "  - Systemd auto-starts on reboot"
echo "  - Telegram alerts on crash/restart"
echo "============================================"
