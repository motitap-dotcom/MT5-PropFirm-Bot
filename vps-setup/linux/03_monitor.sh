#!/bin/bash
#=============================================================================
# PropFirmBot - VPS Health Monitor for Ubuntu (UPGRADED)
# Features: Auto-restart + Telegram alerts + Email alerts
# Run: chmod +x 03_monitor.sh && sudo ./03_monitor.sh
#=============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# === CONFIGURATION ===
TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
ALERT_EMAIL="motitap@gmail.com"
# =====================

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  PropFirmBot - VPS Monitor Setup${NC}"
echo -e "${CYAN}  Auto-restart + Telegram + Email Alerts${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# --- Check root ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Please run as root: sudo ./03_monitor.sh${NC}"
    exit 1
fi

ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(eval echo "~$ACTUAL_USER")
BOT_DIR="$ACTUAL_HOME/MT5-PropFirm-Bot"
LOGS_DIR="$ACTUAL_HOME/PropFirmBot/logs"
SCRIPTS_DIR="$ACTUAL_HOME/PropFirmBot/scripts"
STATE_DIR="$ACTUAL_HOME/PropFirmBot/state"
MT5_PATH="$ACTUAL_HOME/.wine/drive_c/Program Files/MetaTrader 5"

mkdir -p "$LOGS_DIR" "$SCRIPTS_DIR" "$STATE_DIR"

# ===================================================
# [1/6] Install email support (msmtp)
# ===================================================
echo -e "${YELLOW}[1/6] Installing email support (msmtp)...${NC}"

apt-get update -qq
apt-get install -y -qq msmtp msmtp-mta mailutils > /dev/null 2>&1 || true

# Configure msmtp for Gmail
cat > /etc/msmtprc << 'MSMTP_EOF'
# Gmail SMTP configuration for PropFirmBot alerts
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        gmail
host           smtp.gmail.com
port           587
from           propfirmbot.alert@gmail.com
user           GMAIL_USER_PLACEHOLDER
password       GMAIL_APP_PASSWORD_PLACEHOLDER

account default : gmail
MSMTP_EOF

chmod 600 /etc/msmtprc
echo -e "${YELLOW}  [!] Email requires Gmail App Password - see instructions below${NC}"
echo -e "${GREEN}[OK] msmtp installed${NC}"

# ===================================================
# [2/6] Create Xvfb service (virtual display)
# ===================================================
echo ""
echo -e "${YELLOW}[2/6] Creating Xvfb service...${NC}"

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

systemctl daemon-reload
systemctl enable xvfb.service
systemctl start xvfb.service 2>/dev/null || true
echo -e "${GREEN}[OK] Xvfb service created${NC}"

# ===================================================
# [3/6] Create MT5 systemd service with auto-restart
# ===================================================
echo ""
echo -e "${YELLOW}[3/6] Creating MT5 service with auto-restart...${NC}"

cat > /etc/systemd/system/mt5.service << SERVICE_EOF
[Unit]
Description=MetaTrader 5 Trading Terminal
After=network.target xvfb.service
Requires=xvfb.service

[Service]
Type=simple
User=$ACTUAL_USER
Environment=DISPLAY=:99
Environment=WINEPREFIX=$ACTUAL_HOME/.wine
ExecStart=/usr/bin/wine "$MT5_PATH/terminal64.exe"
Restart=always
RestartSec=30
StartLimitIntervalSec=600
StartLimitBurst=10

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable mt5.service
echo -e "${GREEN}[OK] MT5 service created (auto-start on boot + auto-restart on crash)${NC}"

# ===================================================
# [4/6] Create VNC service
# ===================================================
echo ""
echo -e "${YELLOW}[4/6] Creating VNC service...${NC}"

cat > /etc/systemd/system/x11vnc.service << SERVICE_EOF
[Unit]
Description=x11vnc VNC Server
After=xvfb.service
Requires=xvfb.service

[Service]
Type=simple
User=$ACTUAL_USER
Environment=DISPLAY=:99
ExecStart=/usr/bin/x11vnc -display :99 -forever -shared -rfbport 5900 -nopw
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable x11vnc.service
systemctl start x11vnc.service 2>/dev/null || true
echo -e "${GREEN}[OK] VNC service created (auto-start + auto-restart)${NC}"

# ===================================================
# [5/6] Create SMART watchdog script
# ===================================================
echo ""
echo -e "${YELLOW}[5/6] Creating smart watchdog script...${NC}"

cat > "$SCRIPTS_DIR/watchdog.sh" << 'WATCHDOG_EOF'
#!/bin/bash
#=============================================================================
# PropFirmBot Smart Watchdog
# - Checks MT5 every 2 minutes (via cron)
# - Auto-restarts if MT5 is down
# - Sends Telegram alert on state change (down/up)
# - Sends Email alert on state change
# - Tracks state to avoid spam
# - Also monitors VNC
#=============================================================================

# === Configuration ===
TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
ALERT_EMAIL="motitap@gmail.com"

LOG_FILE="$HOME/PropFirmBot/logs/watchdog.log"
STATE_FILE="$HOME/PropFirmBot/state/mt5_status"
RESTART_COUNT_FILE="$HOME/PropFirmBot/state/restart_count"
LAST_ALERT_FILE="$HOME/PropFirmBot/state/last_alert_time"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
TIMESTAMP_SHORT=$(date '+%d/%m %H:%M')

mkdir -p "$HOME/PropFirmBot/logs" "$HOME/PropFirmBot/state"

# === Functions ===

send_telegram() {
    local message="$1"
    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=HTML" \
        > /dev/null 2>&1 || true
}

send_email() {
    local subject="$1"
    local body="$2"
    # Only send if msmtp is properly configured (not placeholder)
    if grep -q "PLACEHOLDER" /etc/msmtprc 2>/dev/null; then
        return 0
    fi
    echo -e "Subject: ${subject}\nFrom: propfirmbot.alert@gmail.com\nTo: ${ALERT_EMAIL}\n\n${body}" | \
        msmtp "${ALERT_EMAIL}" 2>/dev/null || true
}

get_previous_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "unknown"
    fi
}

save_state() {
    echo "$1" > "$STATE_FILE"
}

get_restart_count() {
    if [ -f "$RESTART_COUNT_FILE" ]; then
        cat "$RESTART_COUNT_FILE"
    else
        echo "0"
    fi
}

increment_restart_count() {
    local count=$(get_restart_count)
    echo $((count + 1)) > "$RESTART_COUNT_FILE"
}

reset_restart_count() {
    echo "0" > "$RESTART_COUNT_FILE"
}

get_system_info() {
    local uptime_info=$(uptime -p 2>/dev/null || echo "N/A")
    local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{printf "%.1f", $2}' 2>/dev/null || echo "N/A")
    local ram=$(free | awk '/Mem/{printf "%.1f", $3/$2*100}' 2>/dev/null || echo "N/A")
    local disk=$(df -h / | awk 'NR==2{print $5}' 2>/dev/null || echo "N/A")
    echo "CPU: ${cpu}% | RAM: ${ram}% | Disk: ${disk} | ${uptime_info}"
}

# === Main Logic ===

PREV_STATE=$(get_previous_state)
MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
VNC_PID=$(pgrep -f "x11vnc" 2>/dev/null || true)

# --- Check VNC ---
if [ -z "$VNC_PID" ]; then
    echo "$TIMESTAMP [WARN] VNC not running, restarting..." >> "$LOG_FILE"
    sudo systemctl restart x11vnc.service 2>/dev/null || \
        (export DISPLAY=:99 && x11vnc -display :99 -forever -shared -rfbport 5900 -nopw -bg 2>/dev/null || true)
fi

# --- Check MT5 ---
if [ -n "$MT5_PID" ]; then
    # ===== MT5 IS RUNNING =====

    if [ "$PREV_STATE" = "down" ]; then
        # State changed: was down, now up!
        RESTART_NUM=$(get_restart_count)
        SYS_INFO=$(get_system_info)

        MSG="<b>PropFirmBot - MT5 RECOVERED</b>

MT5 is back online!
PID: ${MT5_PID}
Time: ${TIMESTAMP_SHORT}
Restarts today: ${RESTART_NUM}

System: ${SYS_INFO}"

        send_telegram "$MSG"
        send_email "PropFirmBot - MT5 RECOVERED" "MT5 is back online!\nPID: ${MT5_PID}\nTime: ${TIMESTAMP}\nRestarts: ${RESTART_NUM}\nSystem: ${SYS_INFO}"

        echo "$TIMESTAMP [RECOVERED] MT5 back online (PID: $MT5_PID) after $RESTART_NUM restart(s)" >> "$LOG_FILE"
    fi

    save_state "up"
    # Log OK every 15 minutes (every 7th check if cron is every 2 min)
    MINUTE=$(date '+%M')
    if [ "$((MINUTE % 15))" -lt 2 ]; then
        echo "$TIMESTAMP [OK] MT5 running (PID: $MT5_PID)" >> "$LOG_FILE"
    fi

else
    # ===== MT5 IS DOWN =====

    echo "$TIMESTAMP [ALERT] MT5 not running! Attempting restart..." >> "$LOG_FILE"

    # Try restart via systemd first, then direct wine
    sudo systemctl restart mt5.service 2>/dev/null || true
    sleep 15

    NEW_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)

    if [ -z "$NEW_PID" ]; then
        # systemd failed, try direct wine
        echo "$TIMESTAMP [WARN] systemd restart failed, trying direct wine..." >> "$LOG_FILE"
        export DISPLAY=:99
        export WINEPREFIX="$HOME/.wine"
        wine "$HOME/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" &
        sleep 20
        NEW_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
    fi

    increment_restart_count
    RESTART_NUM=$(get_restart_count)
    SYS_INFO=$(get_system_info)

    if [ -n "$NEW_PID" ]; then
        # Restart succeeded
        save_state "up"

        if [ "$PREV_STATE" != "down" ] || [ "$RESTART_NUM" -le 3 ]; then
            MSG="<b>PropFirmBot - MT5 RESTARTED</b>

MT5 was down and has been restarted automatically.
New PID: ${NEW_PID}
Time: ${TIMESTAMP_SHORT}
Restart #${RESTART_NUM}

System: ${SYS_INFO}"

            send_telegram "$MSG"
            send_email "PropFirmBot - MT5 Auto-Restarted (#${RESTART_NUM})" "MT5 was down and restarted.\nNew PID: ${NEW_PID}\nTime: ${TIMESTAMP}\nRestart #${RESTART_NUM}\nSystem: ${SYS_INFO}"
        fi

        echo "$TIMESTAMP [OK] MT5 restarted successfully (PID: $NEW_PID), restart #$RESTART_NUM" >> "$LOG_FILE"
    else
        # Restart FAILED
        save_state "down"

        MSG="<b>PROPFIRMBOT - MT5 DOWN!</b>

MT5 is NOT running and restart FAILED!
Time: ${TIMESTAMP_SHORT}
Failed restart attempts: ${RESTART_NUM}

System: ${SYS_INFO}

<b>ACTION REQUIRED - Check VPS immediately!</b>
VNC: 77.237.234.2:5900
SSH: ssh root@77.237.234.2"

        send_telegram "$MSG"
        send_email "URGENT: PropFirmBot MT5 DOWN - Restart Failed!" "MT5 is NOT running and restart FAILED!\nTime: ${TIMESTAMP}\nFailed attempts: ${RESTART_NUM}\nSystem: ${SYS_INFO}\n\nACTION REQUIRED!\nVNC: 77.237.234.2:5900\nSSH: ssh root@77.237.234.2"

        echo "$TIMESTAMP [ERROR] MT5 restart FAILED! Alert sent. Restart #$RESTART_NUM" >> "$LOG_FILE"
    fi
fi

# --- Reset restart count daily at midnight ---
HOUR=$(date '+%H')
MINUTE=$(date '+%M')
if [ "$HOUR" = "00" ] && [ "$MINUTE" -lt 3 ]; then
    reset_restart_count
fi

# --- Keep log manageable (last 2000 lines) ---
if [ -f "$LOG_FILE" ]; then
    tail -2000 "$LOG_FILE" > "${LOG_FILE}.tmp"
    mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi
WATCHDOG_EOF

chmod +x "$SCRIPTS_DIR/watchdog.sh"
chown "$ACTUAL_USER:$ACTUAL_USER" "$SCRIPTS_DIR/watchdog.sh"
echo -e "${GREEN}[OK] Smart watchdog created${NC}"

# ===================================================
# [6/6] Create daily health report + Set up cron
# ===================================================
echo ""
echo -e "${YELLOW}[6/6] Creating daily report + cron jobs...${NC}"

cat > "$SCRIPTS_DIR/daily_report.sh" << 'REPORT_EOF'
#!/bin/bash
# Daily VPS Health Report - Runs at 06:00 UTC (08:00 Israel time)
# Sends summary to Telegram + Email

TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
ALERT_EMAIL="motitap@gmail.com"

LOG_FILE="$HOME/PropFirmBot/logs/daily_report.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# System info
UPTIME=$(uptime -p 2>/dev/null || echo "N/A")
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{printf "%.1f", $2}' 2>/dev/null || echo "N/A")
RAM_USAGE=$(free | awk '/Mem/{printf "%.1f", $3/$2*100}' 2>/dev/null || echo "N/A")
DISK_USAGE=$(df -h / | awk 'NR==2{print $5}' 2>/dev/null || echo "N/A")

# MT5 status
MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
if [ -n "$MT5_PID" ]; then
    MT5_STATUS="RUNNING (PID: $MT5_PID)"
    MT5_EMOJI="OK"
else
    MT5_STATUS="NOT RUNNING!"
    MT5_EMOJI="ALERT"
fi

# VNC status
VNC_PID=$(pgrep -f "x11vnc" 2>/dev/null || true)
if [ -n "$VNC_PID" ]; then
    VNC_STATUS="RUNNING"
else
    VNC_STATUS="NOT RUNNING"
fi

# Restart count
RESTART_COUNT="0"
if [ -f "$HOME/PropFirmBot/state/restart_count" ]; then
    RESTART_COUNT=$(cat "$HOME/PropFirmBot/state/restart_count")
fi

# Last 5 watchdog alerts
RECENT_ALERTS=$(grep -E "\[ALERT\]|\[ERROR\]|\[RECOVERED\]" "$HOME/PropFirmBot/logs/watchdog.log" 2>/dev/null | tail -5 || echo "No alerts")

# Send Telegram daily report
MSG="<b>PropFirmBot - Daily Report</b>

Date: $(date '+%d/%m/%Y %H:%M')

<b>MT5:</b> ${MT5_STATUS}
<b>VNC:</b> ${VNC_STATUS}

<b>System:</b>
CPU: ${CPU_USAGE}%
RAM: ${RAM_USAGE}%
Disk: ${DISK_USAGE}
${UPTIME}

<b>Restarts (24h):</b> ${RESTART_COUNT}

<b>Recent events:</b>
${RECENT_ALERTS}"

curl -s -X POST \
    "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=${MSG}" \
    -d "parse_mode=HTML" \
    > /dev/null 2>&1 || true

# Save to log
echo "=== Daily Report: $TIMESTAMP ===" >> "$LOG_FILE"
echo "MT5: $MT5_STATUS | VNC: $VNC_STATUS" >> "$LOG_FILE"
echo "CPU: ${CPU_USAGE}% | RAM: ${RAM_USAGE}% | Disk: ${DISK_USAGE}" >> "$LOG_FILE"
echo "Restarts (24h): $RESTART_COUNT" >> "$LOG_FILE"
echo "---" >> "$LOG_FILE"

# Keep log manageable
if [ -f "$LOG_FILE" ]; then
    tail -500 "$LOG_FILE" > "${LOG_FILE}.tmp"
    mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi
REPORT_EOF

chmod +x "$SCRIPTS_DIR/daily_report.sh"
chown "$ACTUAL_USER:$ACTUAL_USER" "$SCRIPTS_DIR/daily_report.sh"

# --- Allow user to restart services without password ---
cat > "/etc/sudoers.d/mt5-watchdog" << SUDOERS_EOF
$ACTUAL_USER ALL=(ALL) NOPASSWD: /bin/systemctl restart mt5.service
$ACTUAL_USER ALL=(ALL) NOPASSWD: /bin/systemctl restart x11vnc.service
$ACTUAL_USER ALL=(ALL) NOPASSWD: /bin/systemctl restart xvfb.service
SUDOERS_EOF
chmod 440 "/etc/sudoers.d/mt5-watchdog"

# --- Set up cron jobs ---
CRON_TMP=$(mktemp)
crontab -u "$ACTUAL_USER" -l 2>/dev/null > "$CRON_TMP" || true

# Remove existing PropFirmBot entries
sed -i '/PropFirmBot/d' "$CRON_TMP"

# Add watchdog (every 2 minutes)
echo "*/2 * * * * $SCRIPTS_DIR/watchdog.sh  # PropFirmBot watchdog" >> "$CRON_TMP"

# Add daily report (06:00 UTC = 08:00 Israel time)
echo "0 6 * * * $SCRIPTS_DIR/daily_report.sh  # PropFirmBot daily report" >> "$CRON_TMP"

crontab -u "$ACTUAL_USER" "$CRON_TMP"
rm "$CRON_TMP"

echo -e "${GREEN}[OK] Cron jobs configured${NC}"

# Fix ownership
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/PropFirmBot"

# --- Initialize state ---
MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
if [ -n "$MT5_PID" ]; then
    echo "up" > "$STATE_DIR/mt5_status"
else
    echo "unknown" > "$STATE_DIR/mt5_status"
fi
echo "0" > "$STATE_DIR/restart_count"
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$STATE_DIR"

# === Send test Telegram message ===
echo ""
echo -e "${YELLOW}Sending test Telegram alert...${NC}"
TEST_MSG="<b>PropFirmBot - Monitoring Active!</b>

Watchdog is now protecting your bot.

What it does:
- Checks MT5 every 2 minutes
- Auto-restarts if MT5 crashes
- Sends Telegram alert if MT5 goes down
- Daily report at 08:00 Israel time
- Also monitors VNC connection

You will receive alerts here if anything goes wrong."

curl -s -X POST \
    "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=${TEST_MSG}" \
    -d "parse_mode=HTML" \
    > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[OK] Test Telegram message sent!${NC}"
else
    echo -e "${RED}[WARN] Could not send test Telegram message${NC}"
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Monitoring Setup Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${CYAN}What's active:${NC}"
echo -e "  [*] Xvfb service   - Virtual display (:99)"
echo -e "  [*] MT5 service    - Auto-start + auto-restart on crash"
echo -e "  [*] VNC service    - Auto-start + auto-restart"
echo -e "  [*] Watchdog       - Checks MT5 every 2 min"
echo -e "  [*] Daily report   - Telegram report at 08:00 Israel time"
echo ""
echo -e "${CYAN}Alerts:${NC}"
echo -e "  [*] Telegram: Instant alert when MT5 goes down"
echo -e "  [*] Telegram: Alert when MT5 recovers"
echo -e "  [*] Telegram: Daily health report"
echo -e "  [ ] Email: Configure Gmail App Password (see below)"
echo ""
echo -e "${CYAN}Logs:${NC}"
echo -e "  Watchdog: ${YELLOW}$LOGS_DIR/watchdog.log${NC}"
echo -e "  Reports:  ${YELLOW}$LOGS_DIR/daily_report.log${NC}"
echo ""
echo -e "${CYAN}Commands:${NC}"
echo -e "  Start MT5:   ${YELLOW}sudo systemctl start mt5${NC}"
echo -e "  Stop MT5:    ${YELLOW}sudo systemctl stop mt5${NC}"
echo -e "  MT5 status:  ${YELLOW}sudo systemctl status mt5${NC}"
echo -e "  View logs:   ${YELLOW}tail -f $LOGS_DIR/watchdog.log${NC}"
echo ""
echo -e "${YELLOW}============================================${NC}"
echo -e "${YELLOW}  EMAIL SETUP (Optional):${NC}"
echo -e "${YELLOW}============================================${NC}"
echo ""
echo -e "  To also get email alerts, you need a Gmail App Password:"
echo -e "  1. Go to: ${CYAN}https://myaccount.google.com/apppasswords${NC}"
echo -e "  2. Create an App Password for 'Mail'"
echo -e "  3. Run this command (replace YOUR_APP_PASSWORD):"
echo -e ""
echo -e "  ${YELLOW}sudo sed -i 's/GMAIL_USER_PLACEHOLDER/motitap@gmail.com/' /etc/msmtprc${NC}"
echo -e "  ${YELLOW}sudo sed -i 's/GMAIL_APP_PASSWORD_PLACEHOLDER/YOUR_APP_PASSWORD/' /etc/msmtprc${NC}"
echo ""
echo -e "  Then test with: ${YELLOW}echo 'Test' | mail -s 'Test' motitap@gmail.com${NC}"
echo ""
