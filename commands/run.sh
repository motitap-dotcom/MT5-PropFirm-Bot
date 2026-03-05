#!/bin/bash
# =============================================================
# Full Diagnostic + Fix Script
# Checks everything and fixes what's broken
# =============================================================

echo "============================================"
echo "  FULL VPS DIAGNOSTIC + FIX"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
SCRIPTS_DIR="/root/PropFirmBot/scripts"
STATE_DIR="/root/PropFirmBot/state"
LOGS_DIR="/root/PropFirmBot/logs"
TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"

# ============ SECTION 1: CURRENT STATE ============
echo "=== [1] CURRENT STATE ==="

echo "--- MT5 Process ---"
if pgrep -f terminal64.exe > /dev/null 2>&1; then
    echo "MT5: RUNNING"
    ps aux | grep terminal64 | grep -v grep
else
    echo "MT5: NOT RUNNING!"
fi
echo ""

echo "--- Xvfb ---"
if pgrep -x Xvfb > /dev/null 2>&1; then
    echo "Xvfb: RUNNING"
else
    echo "Xvfb: NOT RUNNING!"
fi
echo ""

echo "--- x11vnc ---"
if pgrep -f x11vnc > /dev/null 2>&1; then
    echo "VNC: RUNNING"
else
    echo "VNC: NOT RUNNING!"
fi
echo ""

echo "--- Wine ---"
wine --version 2>/dev/null || echo "Wine: NOT FOUND!"
echo ""

# ============ SECTION 2: SYSTEMD SERVICES ============
echo "=== [2] SYSTEMD SERVICES ==="

echo "--- xvfb.service ---"
if [ -f /etc/systemd/system/xvfb.service ]; then
    echo "EXISTS"
    systemctl is-enabled xvfb.service 2>/dev/null || echo "NOT ENABLED"
    systemctl is-active xvfb.service 2>/dev/null || echo "NOT ACTIVE"
else
    echo "MISSING - will create"
fi
echo ""

echo "--- mt5.service ---"
if [ -f /etc/systemd/system/mt5.service ]; then
    echo "EXISTS"
    systemctl is-enabled mt5.service 2>/dev/null || echo "NOT ENABLED"
    systemctl is-active mt5.service 2>/dev/null || echo "NOT ACTIVE"
    echo "Content:"
    cat /etc/systemd/system/mt5.service
else
    echo "MISSING - will create"
fi
echo ""

echo "--- x11vnc.service ---"
if [ -f /etc/systemd/system/x11vnc.service ]; then
    echo "EXISTS"
    systemctl is-enabled x11vnc.service 2>/dev/null || echo "NOT ENABLED"
    systemctl is-active x11vnc.service 2>/dev/null || echo "NOT ACTIVE"
else
    echo "MISSING - will create"
fi
echo ""

# ============ SECTION 3: WATCHDOG & CRON ============
echo "=== [3] WATCHDOG & CRON ==="

echo "--- Cron jobs ---"
crontab -l 2>/dev/null || echo "No crontab configured"
echo ""

echo "--- Watchdog script ---"
if [ -f "$SCRIPTS_DIR/watchdog.sh" ]; then
    echo "EXISTS at $SCRIPTS_DIR/watchdog.sh"
else
    echo "MISSING"
fi
echo ""

echo "--- Watchdog log (last 10 lines) ---"
if [ -f "$LOGS_DIR/watchdog.log" ]; then
    tail -10 "$LOGS_DIR/watchdog.log"
else
    echo "No watchdog log found"
fi
echo ""

# ============ SECTION 4: MT5 LOGS ============
echo "=== [4] MT5 LOGS ==="

echo "--- Latest EA log ---"
LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "File: $(basename "$LATEST_LOG") ($(stat -c%s "$LATEST_LOG" 2>/dev/null || echo '?') bytes)"
    echo "Last 30 lines:"
    cat "$LATEST_LOG" 2>/dev/null | tr -d '\0' | tail -30
else
    echo "No EA logs found"
fi
echo ""

echo "--- Latest Terminal log ---"
TERM_LOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
if [ -n "$TERM_LOG" ]; then
    echo "File: $(basename "$TERM_LOG") ($(stat -c%s "$TERM_LOG" 2>/dev/null || echo '?') bytes)"
    echo "Last 20 lines:"
    cat "$TERM_LOG" 2>/dev/null | tr -d '\0' | tail -20
else
    echo "No terminal logs found"
fi
echo ""

# ============ SECTION 5: FIX EVERYTHING ============
echo "=== [5] FIXING... ==="

# 5.1: Create directories
mkdir -p "$SCRIPTS_DIR" "$STATE_DIR" "$LOGS_DIR"
echo "5.1 Directories: OK"

# 5.2: Fix DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
echo "5.2 DNS: FIXED"

# 5.3: Create/fix xvfb.service
cat > /etc/systemd/system/xvfb.service << 'XVFB_EOF'
[Unit]
Description=X Virtual Frame Buffer for MT5
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/Xvfb :99 -screen 0 1280x1024x24
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
XVFB_EOF
echo "5.3 xvfb.service: CREATED"

# 5.4: Create/fix mt5.service
cat > /etc/systemd/system/mt5.service << SERVICE_EOF
[Unit]
Description=MetaTrader 5 Trading Terminal
After=network.target xvfb.service
Requires=xvfb.service

[Service]
Type=simple
User=root
Environment=DISPLAY=:99
Environment=WINEPREFIX=/root/.wine
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/wine "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" /portable
Restart=always
RestartSec=30
StartLimitIntervalSec=600
StartLimitBurst=10

[Install]
WantedBy=multi-user.target
SERVICE_EOF
echo "5.4 mt5.service: CREATED"

# 5.5: Create/fix x11vnc.service
cat > /etc/systemd/system/x11vnc.service << SERVICE_EOF
[Unit]
Description=x11vnc VNC Server
After=xvfb.service
Requires=xvfb.service

[Service]
Type=simple
User=root
Environment=DISPLAY=:99
ExecStart=/usr/bin/x11vnc -display :99 -forever -shared -rfbport 5900 -nopw
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE_EOF
echo "5.5 x11vnc.service: CREATED"

# 5.6: Reload and enable services
systemctl daemon-reload
systemctl enable xvfb.service mt5.service x11vnc.service
echo "5.6 Services: ENABLED"

# 5.7: Start Xvfb if not running
if ! pgrep -x Xvfb > /dev/null 2>&1; then
    systemctl start xvfb.service
    sleep 2
    echo "5.7 Xvfb: STARTED"
else
    echo "5.7 Xvfb: ALREADY RUNNING"
fi

# 5.8: Start VNC if not running
if ! pgrep -f x11vnc > /dev/null 2>&1; then
    systemctl start x11vnc.service
    sleep 2
    echo "5.8 VNC: STARTED"
else
    echo "5.8 VNC: ALREADY RUNNING"
fi

# 5.9: Write MT5 config
mkdir -p "$MT5/config" 2>/dev/null
cat > "$MT5/config/common.ini" << 'EOF'
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
EOF
echo "5.9 MT5 Config: WRITTEN"

# 5.10: Restart MT5
echo "5.10 Restarting MT5..."
pkill -f terminal64 2>/dev/null || true
sleep 3
pkill -9 -f terminal64 2>/dev/null || true
wineserver -k 2>/dev/null || true
sleep 2

export DISPLAY=:99
export WINEPREFIX=/root/.wine
cd "$MT5"
nohup wine terminal64.exe /portable /login:11797849 /password:gazDE62## /server:FundedNext-Server > /tmp/mt5_wine.log 2>&1 &
disown
sleep 15

if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "5.10 MT5: RUNNING!"
    ps aux | grep terminal64 | grep -v grep
else
    echo "5.10 MT5: FAILED TO START - trying via systemd..."
    systemctl start mt5.service
    sleep 20
    if pgrep -f terminal64 > /dev/null 2>&1; then
        echo "5.10 MT5: RUNNING (via systemd)!"
    else
        echo "5.10 MT5: STILL NOT RUNNING!"
    fi
fi

# 5.11: Create watchdog script
cat > "$SCRIPTS_DIR/watchdog.sh" << 'WATCHDOG_EOF'
#!/bin/bash
TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
LOG_FILE="$HOME/PropFirmBot/logs/watchdog.log"
STATE_FILE="$HOME/PropFirmBot/state/mt5_status"
RESTART_COUNT_FILE="$HOME/PropFirmBot/state/restart_count"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
mkdir -p "$HOME/PropFirmBot/logs" "$HOME/PropFirmBot/state"

send_telegram() {
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" -d "text=${1}" -d "parse_mode=HTML" > /dev/null 2>&1 || true
}

PREV_STATE="unknown"
[ -f "$STATE_FILE" ] && PREV_STATE=$(cat "$STATE_FILE")
RESTART_COUNT=0
[ -f "$RESTART_COUNT_FILE" ] && RESTART_COUNT=$(cat "$RESTART_COUNT_FILE")

# Check VNC
if ! pgrep -f x11vnc > /dev/null 2>&1; then
    echo "$TIMESTAMP [WARN] VNC not running, restarting..." >> "$LOG_FILE"
    systemctl restart x11vnc.service 2>/dev/null || \
        (export DISPLAY=:99 && x11vnc -display :99 -forever -shared -rfbport 5900 -nopw -bg 2>/dev/null || true)
fi

# Check MT5
MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)

if [ -n "$MT5_PID" ]; then
    if [ "$PREV_STATE" = "down" ]; then
        send_telegram "<b>PropFirmBot - MT5 RECOVERED</b>
MT5 is back online! PID: ${MT5_PID}
Time: $(date '+%d/%m %H:%M')"
        echo "$TIMESTAMP [RECOVERED] MT5 back online (PID: $MT5_PID)" >> "$LOG_FILE"
    fi
    echo "up" > "$STATE_FILE"
    MINUTE=$(date '+%M')
    if [ "$((MINUTE % 15))" -lt 2 ]; then
        echo "$TIMESTAMP [OK] MT5 running (PID: $MT5_PID)" >> "$LOG_FILE"
    fi
else
    echo "$TIMESTAMP [ALERT] MT5 not running! Restarting..." >> "$LOG_FILE"
    systemctl restart mt5.service 2>/dev/null || true
    sleep 15
    NEW_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
    if [ -z "$NEW_PID" ]; then
        export DISPLAY=:99
        export WINEPREFIX=/root/.wine
        cd "/root/.wine/drive_c/Program Files/MetaTrader 5"
        nohup wine terminal64.exe /portable /login:11797849 /password:gazDE62## /server:FundedNext-Server > /tmp/mt5_wine.log 2>&1 &
        disown
        sleep 20
        NEW_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
    fi
    RESTART_COUNT=$((RESTART_COUNT + 1))
    echo "$RESTART_COUNT" > "$RESTART_COUNT_FILE"
    if [ -n "$NEW_PID" ]; then
        echo "up" > "$STATE_FILE"
        send_telegram "<b>PropFirmBot - MT5 RESTARTED</b>
MT5 was down, restarted automatically.
PID: ${NEW_PID} | Restart #${RESTART_COUNT}"
        echo "$TIMESTAMP [OK] MT5 restarted (PID: $NEW_PID) #$RESTART_COUNT" >> "$LOG_FILE"
    else
        echo "down" > "$STATE_FILE"
        send_telegram "<b>PROPFIRMBOT - MT5 DOWN!</b>
MT5 NOT running, restart FAILED!
Restart attempts: ${RESTART_COUNT}
ACTION REQUIRED!
VNC: 77.237.234.2:5900
SSH: ssh root@77.237.234.2"
        echo "$TIMESTAMP [ERROR] MT5 restart FAILED! #$RESTART_COUNT" >> "$LOG_FILE"
    fi
fi

# Reset count daily
[ "$(date '+%H')" = "00" ] && [ "$(date '+%M')" -lt 3 ] && echo "0" > "$RESTART_COUNT_FILE"

# Trim log
[ -f "$LOG_FILE" ] && tail -2000 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
WATCHDOG_EOF
chmod +x "$SCRIPTS_DIR/watchdog.sh"
echo "5.11 Watchdog: CREATED"

# 5.12: Create daily report
cat > "$SCRIPTS_DIR/daily_report.sh" << 'REPORT_EOF'
#!/bin/bash
TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
[ -n "$MT5_PID" ] && MT5_STATUS="RUNNING (PID: $MT5_PID)" || MT5_STATUS="NOT RUNNING!"
VNC_PID=$(pgrep -f "x11vnc" 2>/dev/null || true)
[ -n "$VNC_PID" ] && VNC_STATUS="RUNNING" || VNC_STATUS="NOT RUNNING"
RESTART_COUNT="0"
[ -f "$HOME/PropFirmBot/state/restart_count" ] && RESTART_COUNT=$(cat "$HOME/PropFirmBot/state/restart_count")
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{printf "%.1f", $2}' 2>/dev/null || echo "N/A")
RAM=$(free | awk '/Mem/{printf "%.1f", $3/$2*100}' 2>/dev/null || echo "N/A")
DISK=$(df -h / | awk 'NR==2{print $5}' 2>/dev/null || echo "N/A")
UPTIME=$(uptime -p 2>/dev/null || echo "N/A")
MSG="<b>PropFirmBot - Daily Report</b>
$(date '+%d/%m/%Y %H:%M')
<b>MT5:</b> ${MT5_STATUS}
<b>VNC:</b> ${VNC_STATUS}
<b>System:</b> CPU ${CPU}% | RAM ${RAM}% | Disk ${DISK}
${UPTIME}
<b>Restarts (24h):</b> ${RESTART_COUNT}"
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" -d "text=${MSG}" -d "parse_mode=HTML" > /dev/null 2>&1 || true
REPORT_EOF
chmod +x "$SCRIPTS_DIR/daily_report.sh"
echo "5.12 Daily report: CREATED"

# 5.13: Set up cron
CRON_TMP=$(mktemp)
crontab -l 2>/dev/null > "$CRON_TMP" || true
# Remove old PropFirmBot entries
sed -i '/PropFirmBot/d' "$CRON_TMP"
sed -i '/watchdog/d' "$CRON_TMP"
sed -i '/daily_report/d' "$CRON_TMP"
# Add new entries
echo "*/2 * * * * $SCRIPTS_DIR/watchdog.sh  # PropFirmBot watchdog" >> "$CRON_TMP"
echo "0 6 * * * $SCRIPTS_DIR/daily_report.sh  # PropFirmBot daily report" >> "$CRON_TMP"
crontab "$CRON_TMP"
rm "$CRON_TMP"
echo "5.13 Cron: CONFIGURED"

# Show final cron
echo ""
echo "--- Final crontab ---"
crontab -l
echo ""

# 5.14: Initialize state
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "up" > "$STATE_DIR/mt5_status"
else
    echo "down" > "$STATE_DIR/mt5_status"
fi
echo "0" > "$STATE_DIR/restart_count"
echo "5.14 State: INITIALIZED"

# ============ SECTION 6: FINAL STATUS ============
echo ""
echo "============================================"
echo "  FINAL STATUS"
echo "============================================"
echo ""

echo "MT5:     $(pgrep -f terminal64 > /dev/null 2>&1 && echo 'RUNNING' || echo 'NOT RUNNING')"
echo "Xvfb:   $(pgrep -x Xvfb > /dev/null 2>&1 && echo 'RUNNING' || echo 'NOT RUNNING')"
echo "VNC:    $(pgrep -f x11vnc > /dev/null 2>&1 && echo 'RUNNING' || echo 'NOT RUNNING')"
echo "Cron:   $(crontab -l 2>/dev/null | grep -c watchdog) watchdog entries"
echo ""

echo "Services enabled:"
systemctl is-enabled xvfb.service 2>/dev/null && echo "  xvfb: enabled" || echo "  xvfb: NOT enabled"
systemctl is-enabled mt5.service 2>/dev/null && echo "  mt5: enabled" || echo "  mt5: NOT enabled"
systemctl is-enabled x11vnc.service 2>/dev/null && echo "  x11vnc: enabled" || echo "  x11vnc: NOT enabled"
echo ""

echo "System:"
echo "  Uptime: $(uptime -p 2>/dev/null)"
echo "  Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
echo "  Disk:   $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')"
echo ""

# Send Telegram summary
FINAL_STATUS="$(pgrep -f terminal64 > /dev/null 2>&1 && echo 'RUNNING' || echo 'NOT RUNNING')"
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=<b>PropFirmBot - Full Fix Complete</b>

MT5: ${FINAL_STATUS}
Services: xvfb + mt5 + vnc configured
Watchdog: every 2 min (cron)
Daily report: 08:00 Israel time

All systems configured for auto-restart." \
    -d "parse_mode=HTML" > /dev/null 2>&1 || true

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
