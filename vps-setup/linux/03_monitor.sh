#!/bin/bash
#=============================================================================
# PropFirmBot - VPS Health Monitor for Ubuntu
# Run: chmod +x 03_monitor.sh && sudo ./03_monitor.sh
#=============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  PropFirmBot - VPS Monitor Setup${NC}"
echo -e "${CYAN}  Step 3: Auto-recovery & Monitoring${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# --- Check root ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Please run as root: sudo ./03_monitor.sh${NC}"
    exit 1
fi

ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(eval echo "~$ACTUAL_USER")
BOT_DIR="$ACTUAL_HOME/PropFirmBot"
LOGS_DIR="$BOT_DIR/logs"
SCRIPTS_DIR="$BOT_DIR/scripts"

mkdir -p "$LOGS_DIR" "$SCRIPTS_DIR"

# --- Read MT5 path ---
MT5_PATH=""
if [ -f "$BOT_DIR/mt5_path.txt" ]; then
    MT5_PATH=$(cat "$BOT_DIR/mt5_path.txt")
fi

# --- Create MT5 systemd service ---
echo -e "${YELLOW}[1/4] Creating MT5 service...${NC}"

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
StartLimitIntervalSec=300
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable mt5.service
echo -e "${GREEN}[OK] MT5 service created (auto-start on boot + auto-restart on crash)${NC}"

# --- Create watchdog script ---
echo ""
echo -e "${YELLOW}[2/4] Creating watchdog script...${NC}"

cat > "$SCRIPTS_DIR/watchdog.sh" << 'WATCHDOG_EOF'
#!/bin/bash
# MT5 Watchdog - Checks if MT5 is running and restarts if needed
# Runs every 5 minutes via cron

LOG_FILE="$HOME/PropFirmBot/logs/watchdog.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Check if MT5 process is running
MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)

if [ -n "$MT5_PID" ]; then
    echo "$TIMESTAMP [OK] MT5 running (PID: $MT5_PID)" >> "$LOG_FILE"
else
    echo "$TIMESTAMP [ALERT] MT5 not running! Restarting via systemd..." >> "$LOG_FILE"
    sudo systemctl restart mt5.service 2>/dev/null || true
    sleep 10
    NEW_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
    if [ -n "$NEW_PID" ]; then
        echo "$TIMESTAMP [OK] MT5 restarted successfully (PID: $NEW_PID)" >> "$LOG_FILE"
    else
        echo "$TIMESTAMP [ERROR] MT5 restart FAILED!" >> "$LOG_FILE"
    fi
fi

# Keep log manageable (last 1000 lines)
if [ -f "$LOG_FILE" ]; then
    tail -1000 "$LOG_FILE" > "${LOG_FILE}.tmp"
    mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi
WATCHDOG_EOF

chmod +x "$SCRIPTS_DIR/watchdog.sh"
chown "$ACTUAL_USER:$ACTUAL_USER" "$SCRIPTS_DIR/watchdog.sh"
echo -e "${GREEN}[OK] Watchdog script created${NC}"

# --- Create daily report script ---
echo ""
echo -e "${YELLOW}[3/4] Creating daily report script...${NC}"

cat > "$SCRIPTS_DIR/daily_report.sh" << 'REPORT_EOF'
#!/bin/bash
# Daily VPS Health Report - Runs at midnight UTC

LOG_FILE="$HOME/PropFirmBot/logs/daily_report.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S UTC')

# System info
UPTIME=$(uptime -p)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' 2>/dev/null || echo "N/A")
RAM_USAGE=$(free | awk '/Mem/{printf "%.1f", $3/$2*100}' 2>/dev/null || echo "N/A")
DISK_USAGE=$(df -h / | awk 'NR==2{print $5}' 2>/dev/null || echo "N/A")

# MT5 status
MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
if [ -n "$MT5_PID" ]; then
    MT5_STATUS="RUNNING (PID: $MT5_PID)"
else
    MT5_STATUS="NOT RUNNING - CHECK IMMEDIATELY!"
fi

# Write report
cat >> "$LOG_FILE" << INNER_EOF
========================================
  DAILY VPS HEALTH REPORT
  $TIMESTAMP
========================================

--- System ---
Uptime: $UPTIME
CPU Usage: ${CPU_USAGE}%
RAM Usage: ${RAM_USAGE}%
Disk Usage: $DISK_USAGE

--- MT5 Status ---
MT5: $MT5_STATUS

--- Watchdog (last 10 entries) ---
$(tail -10 "$HOME/PropFirmBot/logs/watchdog.log" 2>/dev/null || echo "No watchdog log yet")

========================================

INNER_EOF

echo "Daily report generated at $TIMESTAMP"
REPORT_EOF

chmod +x "$SCRIPTS_DIR/daily_report.sh"
chown "$ACTUAL_USER:$ACTUAL_USER" "$SCRIPTS_DIR/daily_report.sh"
echo -e "${GREEN}[OK] Daily report script created${NC}"

# --- Set up cron jobs ---
echo ""
echo -e "${YELLOW}[4/4] Setting up cron jobs...${NC}"

# Allow user to restart mt5 service without password
echo "$ACTUAL_USER ALL=(ALL) NOPASSWD: /bin/systemctl restart mt5.service" > "/etc/sudoers.d/mt5-watchdog"
chmod 440 "/etc/sudoers.d/mt5-watchdog"

# Create cron entries for the actual user
CRON_TMP=$(mktemp)
crontab -u "$ACTUAL_USER" -l 2>/dev/null > "$CRON_TMP" || true

# Remove existing PropFirmBot entries
sed -i '/PropFirmBot/d' "$CRON_TMP"

# Add watchdog (every 5 minutes)
echo "*/5 * * * * $SCRIPTS_DIR/watchdog.sh  # PropFirmBot watchdog" >> "$CRON_TMP"

# Add daily report (midnight UTC)
echo "0 0 * * * $SCRIPTS_DIR/daily_report.sh  # PropFirmBot daily report" >> "$CRON_TMP"

crontab -u "$ACTUAL_USER" "$CRON_TMP"
rm "$CRON_TMP"

echo -e "${GREEN}[OK] Cron jobs configured${NC}"

# Fix ownership
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$BOT_DIR"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Monitoring Setup Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${CYAN}Active Services:${NC}"
echo -e "  [*] xvfb.service  - Virtual display (DISPLAY=:99)"
echo -e "  [*] mt5.service   - MT5 auto-start + auto-restart"
echo -e "  [*] Cron watchdog - Checks MT5 every 5 min"
echo -e "  [*] Cron report   - Daily health report at midnight"
echo ""
echo -e "${CYAN}Logs:${NC}"
echo -e "  Watchdog: ${YELLOW}$LOGS_DIR/watchdog.log${NC}"
echo -e "  Reports:  ${YELLOW}$LOGS_DIR/daily_report.log${NC}"
echo ""
echo -e "${CYAN}Useful commands:${NC}"
echo -e "  Start MT5:   ${YELLOW}sudo systemctl start mt5${NC}"
echo -e "  Stop MT5:    ${YELLOW}sudo systemctl stop mt5${NC}"
echo -e "  MT5 status:  ${YELLOW}sudo systemctl status mt5${NC}"
echo -e "  View logs:   ${YELLOW}tail -f $LOGS_DIR/watchdog.log${NC}"
echo ""
