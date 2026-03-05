#!/bin/bash
#=============================================================================
# PropFirmBot - Watchdog Install
# Monitors MT5 process AND EA heartbeat (status.json)
# Auto-restarts MT5 if either goes down
# Run: bash /root/MT5-PropFirm-Bot/vps-setup/linux/install_watchdog.sh
#=============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Installing PropFirmBot Watchdog...${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# Configuration
TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
SCRIPTS_DIR="/root/PropFirmBot/scripts"
LOGS_DIR="/root/PropFirmBot/logs"
STATE_DIR="/root/PropFirmBot/state"
MT5_PATH="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_STATUS_FILE="${MT5_PATH}/MQL5/Files/PropFirmBot/status.json"

mkdir -p "$SCRIPTS_DIR" "$LOGS_DIR" "$STATE_DIR"

# --- Step 1: Create Xvfb service ---
echo -e "${YELLOW}[1/5] Setting up Xvfb service...${NC}"
cat > /etc/systemd/system/xvfb.service << 'EOF'
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
EOF
systemctl daemon-reload
systemctl enable xvfb.service 2>/dev/null
systemctl start xvfb.service 2>/dev/null || true
echo -e "${GREEN}[OK]${NC}"

# --- Step 2: Create MT5 service ---
echo -e "${YELLOW}[2/5] Setting up MT5 auto-restart service...${NC}"
cat > /etc/systemd/system/mt5.service << EOF
[Unit]
Description=MetaTrader 5 Trading Terminal
After=network.target xvfb.service
Requires=xvfb.service

[Service]
Type=simple
User=root
Environment=DISPLAY=:99
Environment=WINEPREFIX=/root/.wine
ExecStart=/usr/bin/wine "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"
Restart=always
RestartSec=30
StartLimitIntervalSec=600
StartLimitBurst=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable mt5.service 2>/dev/null
echo -e "${GREEN}[OK]${NC}"

# --- Step 3: Create VNC service ---
echo -e "${YELLOW}[3/5] Setting up VNC auto-restart service...${NC}"
cat > /etc/systemd/system/x11vnc.service << 'EOF'
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
EOF
systemctl daemon-reload
systemctl enable x11vnc.service 2>/dev/null
systemctl start x11vnc.service 2>/dev/null || true
echo -e "${GREEN}[OK]${NC}"

# --- Step 4: Create smart watchdog (monitors MT5 process + EA heartbeat) ---
echo -e "${YELLOW}[4/5] Creating smart watchdog with EA heartbeat monitoring...${NC}"
cat > "$SCRIPTS_DIR/watchdog.sh" << 'WATCHDOG_EOF'
#!/bin/bash
# PropFirmBot Watchdog v2 - monitors MT5 process AND EA heartbeat via status.json
# Runs every 2 min via cron

TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"

LOG_FILE="/root/PropFirmBot/logs/watchdog.log"
STATE_FILE="/root/PropFirmBot/state/mt5_status"
EA_STATE_FILE="/root/PropFirmBot/state/ea_status"
RESTART_COUNT_FILE="/root/PropFirmBot/state/restart_count"
MT5_PATH="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_STATUS_JSON="${MT5_PATH}/MQL5/Files/PropFirmBot/status.json"

# EA is considered dead if status.json not updated for 10 minutes
EA_HEARTBEAT_MAX_AGE=600

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
TIMESTAMP_SHORT=$(date '+%d/%m %H:%M')

mkdir -p /root/PropFirmBot/logs /root/PropFirmBot/state

send_telegram() {
    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=$1" \
        -d "parse_mode=HTML" \
        > /dev/null 2>&1 || true
}

get_sys_info() {
    CPU=$(top -bn1 | grep 'Cpu(s)' | awk '{printf "%.0f", $2}' 2>/dev/null || echo '?')
    RAM=$(free | awk '/Mem/{printf "%.0f", $3/$2*100}' 2>/dev/null || echo '?')
    echo "CPU: ${CPU}% | RAM: ${RAM}%"
}

restart_mt5() {
    systemctl restart mt5.service 2>/dev/null || true
    sleep 20
    pgrep -f "terminal64.exe" 2>/dev/null || true
}

PREV_MT5_STATE="unknown"
PREV_EA_STATE="unknown"
[ -f "$STATE_FILE" ] && PREV_MT5_STATE=$(cat "$STATE_FILE")
[ -f "$EA_STATE_FILE" ] && PREV_EA_STATE=$(cat "$EA_STATE_FILE")

RESTART_COUNT=0
[ -f "$RESTART_COUNT_FILE" ] && RESTART_COUNT=$(cat "$RESTART_COUNT_FILE")

# ----------------------------------------------------------------
# VNC check
# ----------------------------------------------------------------
VNC_PID=$(pgrep -f "x11vnc" 2>/dev/null || true)
if [ -z "$VNC_PID" ]; then
    echo "$TIMESTAMP [WARN] VNC down, restarting..." >> "$LOG_FILE"
    systemctl restart x11vnc.service 2>/dev/null || \
        (DISPLAY=:99 x11vnc -display :99 -forever -shared -rfbport 5900 -nopw -bg 2>/dev/null || true)
fi

# ----------------------------------------------------------------
# MT5 process check
# ----------------------------------------------------------------
MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)

if [ -n "$MT5_PID" ]; then
    echo "up" > "$STATE_FILE"

    # ----------------------------------------------------------------
    # EA heartbeat check (only matters when MT5 is running)
    # ----------------------------------------------------------------
    EA_ALIVE=false
    EA_AGE=9999

    if [ -f "$EA_STATUS_JSON" ]; then
        LAST_MODIFIED=$(stat -c %Y "$EA_STATUS_JSON" 2>/dev/null || echo 0)
        NOW=$(date +%s)
        EA_AGE=$(( NOW - LAST_MODIFIED ))
        if [ "$EA_AGE" -lt "$EA_HEARTBEAT_MAX_AGE" ]; then
            EA_ALIVE=true
        fi
    fi

    if $EA_ALIVE; then
        # EA is alive and well
        echo "up" > "$EA_STATE_FILE"

        # Notify if EA just recovered
        if [ "$PREV_EA_STATE" = "down" ] || [ "$PREV_EA_STATE" = "unknown" ]; then
            SYS=$(get_sys_info)
            send_telegram "<b>PropFirmBot - EA RECOVERED</b>

EA (PropFirmBot) is running again!
MT5 PID: ${MT5_PID}
EA heartbeat: ${EA_AGE}s ago
Time: ${TIMESTAMP_SHORT}
Restarts: ${RESTART_COUNT}
${SYS}"
            echo "$TIMESTAMP [RECOVERED] EA is alive (heartbeat ${EA_AGE}s ago)" >> "$LOG_FILE"
        fi

        # Log OK every 15 min
        MIN=$(date '+%M')
        [ "$((MIN % 15))" -lt 2 ] && echo "$TIMESTAMP [OK] MT5+EA running (PID: $MT5_PID, heartbeat: ${EA_AGE}s)" >> "$LOG_FILE"

    else
        # MT5 running but EA is dead/not responding
        echo "down" > "$EA_STATE_FILE"
        RESTART_COUNT=$((RESTART_COUNT + 1))
        echo "$RESTART_COUNT" > "$RESTART_COUNT_FILE"

        SYS=$(get_sys_info)

        if [ -f "$EA_STATUS_JSON" ]; then
            PROBLEM="EA heartbeat stale (${EA_AGE}s old - EA stopped responding)"
        else
            PROBLEM="EA status file missing (EA never started or was never attached)"
        fi

        echo "$TIMESTAMP [ALERT] $PROBLEM - restarting MT5..." >> "$LOG_FILE"

        # Restart MT5 - it should reload the chart profile with EA
        systemctl restart mt5.service 2>/dev/null || true
        sleep 25

        NEW_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)

        if [ -n "$NEW_PID" ]; then
            send_telegram "<b>PropFirmBot - EA DOWN, MT5 Restarted</b>

${PROBLEM}
MT5 was restarted to reload EA.
New PID: ${NEW_PID}
Time: ${TIMESTAMP_SHORT}
Restart #${RESTART_COUNT}
${SYS}

<i>If EA still not running after 5 min, attach it manually via VNC:
77.237.234.2:5900</i>"
            echo "$TIMESTAMP [WARN] EA dead - MT5 restarted (PID: $NEW_PID) #$RESTART_COUNT" >> "$LOG_FILE"
        else
            send_telegram "<b>ALERT - MT5 Restart FAILED!</b>

EA was dead and MT5 restart failed!
Time: ${TIMESTAMP_SHORT}
Failed restart #${RESTART_COUNT}
${SYS}

<b>Manual action needed:</b>
VNC: 77.237.234.2:5900
SSH: ssh root@77.237.234.2"
            echo "$TIMESTAMP [ERROR] EA dead + MT5 restart FAILED #$RESTART_COUNT" >> "$LOG_FILE"
        fi
    fi

else
    # MT5 process is completely DOWN
    echo "down" > "$STATE_FILE"
    echo "down" > "$EA_STATE_FILE"

    echo "$TIMESTAMP [ALERT] MT5 not running! Restarting..." >> "$LOG_FILE"

    systemctl restart mt5.service 2>/dev/null || true
    sleep 20
    NEW_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)

    if [ -z "$NEW_PID" ]; then
        # systemd failed, try wine directly
        echo "$TIMESTAMP [WARN] systemd restart failed, trying wine directly..." >> "$LOG_FILE"
        export DISPLAY=:99 WINEPREFIX=/root/.wine
        wine "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" &
        sleep 25
        NEW_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
    fi

    RESTART_COUNT=$((RESTART_COUNT + 1))
    echo "$RESTART_COUNT" > "$RESTART_COUNT_FILE"
    SYS=$(get_sys_info)

    if [ -n "$NEW_PID" ]; then
        echo "up" > "$STATE_FILE"
        send_telegram "<b>PropFirmBot - MT5 Restarted</b>

MT5 was down - restarted automatically!
New PID: ${NEW_PID}
Time: ${TIMESTAMP_SHORT}
Restart #${RESTART_COUNT}
${SYS}

<i>EA will load automatically with saved chart profile.
Check VNC in 2-3 min to confirm EA is active.</i>
VNC: 77.237.234.2:5900"
        echo "$TIMESTAMP [OK] MT5 restarted (PID: $NEW_PID) #$RESTART_COUNT" >> "$LOG_FILE"
    else
        send_telegram "<b>ALERT - MT5 DOWN!</b>

MT5 restart FAILED!
Time: ${TIMESTAMP_SHORT}
Failed restart #${RESTART_COUNT}
${SYS}

<b>Manual action needed:</b>
SSH: ssh root@77.237.234.2
VNC: 77.237.234.2:5900"
        echo "$TIMESTAMP [ERROR] MT5 restart FAILED #$RESTART_COUNT" >> "$LOG_FILE"
    fi
fi

# Reset restart count at midnight
[ "$(date '+%H')" = "00" ] && [ "$(date '+%M')" -lt 3 ] && echo "0" > "$RESTART_COUNT_FILE"

# Keep log small (last 2000 lines)
[ -f "$LOG_FILE" ] && tail -2000 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
WATCHDOG_EOF

chmod +x "$SCRIPTS_DIR/watchdog.sh"

# --- Daily report ---
cat > "$SCRIPTS_DIR/daily_report.sh" << 'REPORT_EOF'
#!/bin/bash
# Daily health report - sent to Telegram at 08:00 Israel time (06:00 UTC)

TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
MT5_PATH="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_STATUS_JSON="${MT5_PATH}/MQL5/Files/PropFirmBot/status.json"

MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
[ -n "$MT5_PID" ] && MT5_STATUS="RUNNING (PID: $MT5_PID)" || MT5_STATUS="NOT RUNNING!"

VNC_PID=$(pgrep -f "x11vnc" 2>/dev/null || true)
[ -n "$VNC_PID" ] && VNC_STATUS="RUNNING" || VNC_STATUS="NOT RUNNING"

EA_STATUS="NOT RUNNING"
if [ -f "$EA_STATUS_JSON" ]; then
    EA_AGE=$(( $(date +%s) - $(stat -c %Y "$EA_STATUS_JSON" 2>/dev/null || echo 0) ))
    if [ "$EA_AGE" -lt 600 ]; then
        EA_STATUS="RUNNING (heartbeat ${EA_AGE}s ago)"
    else
        EA_STATUS="DEAD (last seen ${EA_AGE}s ago)"
    fi
fi

RESTART_COUNT=0
[ -f "/root/PropFirmBot/state/restart_count" ] && RESTART_COUNT=$(cat /root/PropFirmBot/state/restart_count)

RECENT=$(grep -E "\[ALERT\]|\[ERROR\]|\[RECOVERED\]|\[WARN\]" /root/PropFirmBot/logs/watchdog.log 2>/dev/null | tail -5 || echo "No events")

CPU=$(top -bn1 | grep 'Cpu(s)' | awk '{printf "%.0f", $2}' 2>/dev/null || echo '?')
RAM=$(free | awk '/Mem/{printf "%.0f", $3/$2*100}' 2>/dev/null || echo '?')
DISK=$(df -h / | awk 'NR==2{print $5}' 2>/dev/null || echo '?')
UPTIME=$(uptime -p 2>/dev/null || echo 'N/A')

curl -s -X POST \
    "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=<b>PropFirmBot - Daily Report</b>

$(date '+%d/%m/%Y %H:%M')

<b>MT5:</b> ${MT5_STATUS}
<b>EA:</b> ${EA_STATUS}
<b>VNC:</b> ${VNC_STATUS}
<b>CPU:</b> ${CPU}%
<b>RAM:</b> ${RAM}%
<b>Disk:</b> ${DISK}
${UPTIME}

<b>Restarts (24h):</b> ${RESTART_COUNT}

<b>Recent events:</b>
${RECENT}" \
    -d "parse_mode=HTML" \
    > /dev/null 2>&1 || true
REPORT_EOF

chmod +x "$SCRIPTS_DIR/daily_report.sh"
echo -e "${GREEN}[OK]${NC}"

# --- Step 5: Set up cron ---
echo -e "${YELLOW}[5/5] Setting up cron jobs...${NC}"
CRON_TMP=$(mktemp)
crontab -l 2>/dev/null > "$CRON_TMP" || true
sed -i '/PropFirmBot/d' "$CRON_TMP"
echo "*/2 * * * * $SCRIPTS_DIR/watchdog.sh  # PropFirmBot watchdog" >> "$CRON_TMP"
echo "0 6 * * * $SCRIPTS_DIR/daily_report.sh  # PropFirmBot daily report" >> "$CRON_TMP"
crontab "$CRON_TMP"
rm "$CRON_TMP"
echo -e "${GREEN}[OK]${NC}"

# --- Initialize state ---
MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
[ -n "$MT5_PID" ] && echo "up" > "$STATE_DIR/mt5_status" || echo "unknown" > "$STATE_DIR/mt5_status"
echo "unknown" > "$STATE_DIR/ea_status"
echo "0" > "$STATE_DIR/restart_count"

# --- Send test message ---
echo ""
echo -e "${YELLOW}Sending test Telegram alert...${NC}"
curl -s -X POST \
    "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=<b>PropFirmBot - Watchdog Active!</b>

Monitoring is now protecting your bot:
- MT5 process: checked every 2 minutes
- EA heartbeat: checked via status.json
- Auto-restart: ON (MT5 + EA)
- Telegram alerts: ON
- Daily report: 08:00 Israel time

If the EA stops, watchdog will restart MT5 automatically!" \
    -d "parse_mode=HTML" \
    > /dev/null 2>&1

echo -e "${GREEN}[OK] Test message sent to Telegram${NC}"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Watchdog Installed Successfully!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "  Watchdog: every 2 min"
echo -e "  MT5 process monitoring: ON"
echo -e "  EA heartbeat monitoring: ON (status.json)"
echo -e "  Auto-restart: ON"
echo -e "  Telegram alerts: ON"
echo -e "  Daily report: 08:00 Israel time"
echo ""
echo -e "  View log: ${YELLOW}tail -f /root/PropFirmBot/logs/watchdog.log${NC}"
echo ""
