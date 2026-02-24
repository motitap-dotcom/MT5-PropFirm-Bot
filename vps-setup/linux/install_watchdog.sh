#!/bin/bash
#=============================================================================
# PropFirmBot - Quick Watchdog Install
# Just paste this ONE command in SSH and everything sets up automatically
# Run: bash /root/MT5-PropFirm-Bot/vps-setup/linux/install_watchdog.sh
#=============================================================================

set -e

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

# --- Step 4: Create smart watchdog ---
echo -e "${YELLOW}[4/5] Creating smart watchdog...${NC}"
cat > "$SCRIPTS_DIR/watchdog.sh" << 'WATCHDOG_EOF'
#!/bin/bash
# PropFirmBot Smart Watchdog - checks MT5 every 2 min, restarts + alerts

TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"

LOG_FILE="/root/PropFirmBot/logs/watchdog.log"
STATE_FILE="/root/PropFirmBot/state/mt5_status"
RESTART_COUNT_FILE="/root/PropFirmBot/state/restart_count"

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

PREV_STATE="unknown"
[ -f "$STATE_FILE" ] && PREV_STATE=$(cat "$STATE_FILE")

RESTART_COUNT=0
[ -f "$RESTART_COUNT_FILE" ] && RESTART_COUNT=$(cat "$RESTART_COUNT_FILE")

MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
VNC_PID=$(pgrep -f "x11vnc" 2>/dev/null || true)

# Check VNC
if [ -z "$VNC_PID" ]; then
    echo "$TIMESTAMP [WARN] VNC down, restarting..." >> "$LOG_FILE"
    systemctl restart x11vnc.service 2>/dev/null || \
        (DISPLAY=:99 x11vnc -display :99 -forever -shared -rfbport 5900 -nopw -bg 2>/dev/null || true)
fi

# Check MT5
if [ -n "$MT5_PID" ]; then
    # MT5 is running
    if [ "$PREV_STATE" = "down" ]; then
        SYS_INFO="CPU: $(top -bn1 | grep 'Cpu(s)' | awk '{printf "%.0f", $2}' 2>/dev/null || echo '?')% | RAM: $(free | awk '/Mem/{printf "%.0f", $3/$2*100}' 2>/dev/null || echo '?')%"
        send_telegram "<b>PropFirmBot - MT5 RECOVERED</b>

MT5 is back online!
PID: ${MT5_PID}
Time: ${TIMESTAMP_SHORT}
Restarts: ${RESTART_COUNT}
${SYS_INFO}"
        echo "$TIMESTAMP [RECOVERED] MT5 back online (PID: $MT5_PID)" >> "$LOG_FILE"
    fi
    echo "up" > "$STATE_FILE"

    # Log OK every ~15 min
    MIN=$(date '+%M')
    [ "$((MIN % 14))" -lt 2 ] && echo "$TIMESTAMP [OK] MT5 running (PID: $MT5_PID)" >> "$LOG_FILE"
else
    # MT5 is DOWN - try restart
    echo "$TIMESTAMP [ALERT] MT5 not running! Restarting..." >> "$LOG_FILE"

    systemctl restart mt5.service 2>/dev/null || true
    sleep 15
    NEW_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)

    if [ -z "$NEW_PID" ]; then
        # systemd failed, try wine directly
        echo "$TIMESTAMP [WARN] systemd failed, trying wine directly..." >> "$LOG_FILE"
        export DISPLAY=:99 WINEPREFIX=/root/.wine
        wine "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" &
        sleep 20
        NEW_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
    fi

    RESTART_COUNT=$((RESTART_COUNT + 1))
    echo "$RESTART_COUNT" > "$RESTART_COUNT_FILE"

    SYS_INFO="CPU: $(top -bn1 | grep 'Cpu(s)' | awk '{printf "%.0f", $2}' 2>/dev/null || echo '?')% | RAM: $(free | awk '/Mem/{printf "%.0f", $3/$2*100}' 2>/dev/null || echo '?')%"

    if [ -n "$NEW_PID" ]; then
        echo "up" > "$STATE_FILE"
        send_telegram "<b>PropFirmBot - MT5 RESTARTED</b>

MT5 was down - restarted automatically!
New PID: ${NEW_PID}
Time: ${TIMESTAMP_SHORT}
Restart #${RESTART_COUNT}
${SYS_INFO}"
        echo "$TIMESTAMP [OK] MT5 restarted (PID: $NEW_PID) #$RESTART_COUNT" >> "$LOG_FILE"
    else
        echo "down" > "$STATE_FILE"
        send_telegram "<b>PROPFIRMBOT - MT5 DOWN!</b>

MT5 restart FAILED!
Time: ${TIMESTAMP_SHORT}
Failed attempts: ${RESTART_COUNT}
${SYS_INFO}

<b>Check VPS now!</b>
VNC: 77.237.234.2:5900
SSH: ssh root@77.237.234.2"
        echo "$TIMESTAMP [ERROR] MT5 restart FAILED! #$RESTART_COUNT" >> "$LOG_FILE"
    fi
fi

# Reset count at midnight
[ "$(date '+%H')" = "00" ] && [ "$(date '+%M')" -lt 3 ] && echo "0" > "$RESTART_COUNT_FILE"

# Keep log small
[ -f "$LOG_FILE" ] && tail -2000 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
WATCHDOG_EOF

chmod +x "$SCRIPTS_DIR/watchdog.sh"

# --- Daily report ---
cat > "$SCRIPTS_DIR/daily_report.sh" << 'REPORT_EOF'
#!/bin/bash
# Daily health report - sent to Telegram at 08:00 Israel time

TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"

MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
[ -n "$MT5_PID" ] && MT5_STATUS="RUNNING (PID: $MT5_PID)" || MT5_STATUS="NOT RUNNING!"

VNC_PID=$(pgrep -f "x11vnc" 2>/dev/null || true)
[ -n "$VNC_PID" ] && VNC_STATUS="RUNNING" || VNC_STATUS="NOT RUNNING"

RESTART_COUNT=0
[ -f "/root/PropFirmBot/state/restart_count" ] && RESTART_COUNT=$(cat /root/PropFirmBot/state/restart_count)

RECENT=$(grep -E "\[ALERT\]|\[ERROR\]|\[RECOVERED\]" /root/PropFirmBot/logs/watchdog.log 2>/dev/null | tail -5 || echo "No events")

curl -s -X POST \
    "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=<b>PropFirmBot - Daily Report</b>

$(date '+%d/%m/%Y %H:%M')

<b>MT5:</b> ${MT5_STATUS}
<b>VNC:</b> ${VNC_STATUS}
<b>CPU:</b> $(top -bn1 | grep 'Cpu(s)' | awk '{printf "%.0f", $2}' 2>/dev/null || echo '?')%
<b>RAM:</b> $(free | awk '/Mem/{printf "%.0f", $3/$2*100}' 2>/dev/null || echo '?')%
<b>Disk:</b> $(df -h / | awk 'NR==2{print $5}' 2>/dev/null || echo '?')
$(uptime -p 2>/dev/null)

<b>Restarts (24h):</b> ${RESTART_COUNT}

<b>Events:</b>
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
echo "0" > "$STATE_DIR/restart_count"

# --- Send test message ---
echo ""
echo -e "${YELLOW}Sending test Telegram alert...${NC}"
curl -s -X POST \
    "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=<b>PropFirmBot - Monitoring Active!</b>

Watchdog is now protecting your bot:
- Checks MT5 every 2 minutes
- Auto-restarts if MT5 crashes
- Telegram alert when MT5 goes down/up
- Daily report at 08:00 Israel time
- VNC monitoring included

Everything is set up and running!" \
    -d "parse_mode=HTML" \
    > /dev/null 2>&1

echo -e "${GREEN}[OK] Test message sent to Telegram${NC}"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Watchdog Installed Successfully!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "  Watchdog: checks every 2 min"
echo -e "  MT5 auto-restart: ON"
echo -e "  VNC auto-restart: ON"
echo -e "  Telegram alerts: ON"
echo -e "  Daily report: 08:00 Israel time"
echo ""
echo -e "  View log: ${YELLOW}tail -f /root/PropFirmBot/logs/watchdog.log${NC}"
echo ""
