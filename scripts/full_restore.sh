#!/bin/bash
#=============================================================================
# PropFirmBot - FULL RESTORE: Deploy + Compile + Restart + Watchdog
# Run via GitHub Actions or directly on VPS
#=============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"

MT5_PATH="/root/.wine/drive_c/Program Files/MetaTrader 5"
MQL5_PATH="$MT5_PATH/MQL5"
EA_DEST="$MQL5_PATH/Experts/PropFirmBot"
CONFIG_DEST="$MQL5_PATH/Files/PropFirmBot"
SCRIPTS_DIR="/root/PropFirmBot/scripts"
LOGS_DIR="/root/PropFirmBot/logs"
STATE_DIR="/root/PropFirmBot/state"

send_telegram() {
    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=$1" \
        -d "parse_mode=HTML" \
        > /dev/null 2>&1 || true
}

echo "╔══════════════════════════════════════════════════╗"
echo "║   PropFirmBot - FULL RESTORE                     ║"
echo "║   $(date '+%Y-%m-%d %H:%M:%S UTC')                        ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

#=== STEP 1: Pull latest code ===
echo "━━━ [1/7] Pulling latest code ━━━"
cd /root
if [ -d "MT5-PropFirm-Bot" ]; then
    cd MT5-PropFirm-Bot
    git fetch origin 2>/dev/null || true
    # Try current branch first, fallback to main branch
    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "claude/build-cfd-trading-bot-fl0ld")
    git pull origin "$BRANCH" 2>/dev/null || git pull origin claude/build-cfd-trading-bot-fl0ld 2>/dev/null || true
    echo "✅ Code updated (branch: $BRANCH)"
else
    git clone https://github.com/motitap-dotcom/MT5-PropFirm-Bot.git
    cd MT5-PropFirm-Bot
    git checkout claude/build-cfd-trading-bot-fl0ld 2>/dev/null || true
    echo "✅ Code cloned"
fi

PROJECT_DIR="/root/MT5-PropFirm-Bot"

#=== STEP 2: Stop MT5 gracefully ===
echo ""
echo "━━━ [2/7] Stopping MT5 for clean restart ━━━"
if pgrep -f "terminal64.exe" > /dev/null 2>&1; then
    echo "Stopping MT5..."
    pkill -f "terminal64.exe" 2>/dev/null || true
    sleep 5
    # Force kill if still running
    pkill -9 -f "terminal64.exe" 2>/dev/null || true
    sleep 2
    echo "✅ MT5 stopped"
else
    echo "MT5 was not running"
fi

#=== STEP 3: Deploy EA files ===
echo ""
echo "━━━ [3/7] Deploying EA files ━━━"
mkdir -p "$EA_DEST"

EA_COUNT=0
for file in "$PROJECT_DIR"/EA/*.mq5 "$PROJECT_DIR"/EA/*.mqh; do
    if [ -f "$file" ]; then
        cp -f "$file" "$EA_DEST/"
        echo "   ✅ $(basename "$file")"
        EA_COUNT=$((EA_COUNT + 1))
    fi
done
echo "Copied $EA_COUNT EA files"

# Deploy config files
echo ""
echo "━━━ [4/7] Deploying config files ━━━"
mkdir -p "$CONFIG_DEST"

CFG_COUNT=0
for file in "$PROJECT_DIR"/configs/*.json; do
    if [ -f "$file" ]; then
        cp -f "$file" "$CONFIG_DEST/"
        echo "   ✅ $(basename "$file")"
        CFG_COUNT=$((CFG_COUNT + 1))
    fi
done
echo "Copied $CFG_COUNT config files"

#=== STEP 5: Compile EA ===
echo ""
echo "━━━ [5/7] Compiling EA ━━━"

export DISPLAY=:99
export WINEPREFIX=/root/.wine

# Make sure Xvfb is running
if ! pgrep -x "Xvfb" > /dev/null 2>&1; then
    echo "Starting Xvfb..."
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
fi

# Find MetaEditor
METAEDITOR=""
for name in "metaeditor64.exe" "MetaEditor64.exe"; do
    if [ -f "$MT5_PATH/$name" ]; then
        METAEDITOR="$MT5_PATH/$name"
        break
    fi
done

COMPILE_SUCCESS=false
if [ -n "$METAEDITOR" ]; then
    echo "Found MetaEditor: $(basename "$METAEDITOR")"

    # Remove old .ex5 to ensure fresh compile
    rm -f "$EA_DEST/PropFirmBot.ex5" 2>/dev/null

    # Method 1: Command-line compile
    echo "Attempting command-line compile..."
    timeout 60 wine "$METAEDITOR" /compile:"$EA_DEST/PropFirmBot.mq5" /log > /dev/null 2>&1 || true
    wineserver -w 2>/dev/null || true
    sleep 3

    if [ -f "$EA_DEST/PropFirmBot.ex5" ]; then
        EX5_SIZE=$(stat -c%s "$EA_DEST/PropFirmBot.ex5" 2>/dev/null)
        echo "✅ EA compiled! PropFirmBot.ex5 = ${EX5_SIZE} bytes"
        COMPILE_SUCCESS=true
    else
        echo "Command-line compile didn't create .ex5"

        # Method 2: Try with /include path
        echo "Trying with include path..."
        timeout 60 wine "$METAEDITOR" /compile:"$EA_DEST/PropFirmBot.mq5" /include:"$MQL5_PATH" /log > /dev/null 2>&1 || true
        wineserver -w 2>/dev/null || true
        sleep 3

        if [ -f "$EA_DEST/PropFirmBot.ex5" ]; then
            EX5_SIZE=$(stat -c%s "$EA_DEST/PropFirmBot.ex5" 2>/dev/null)
            echo "✅ EA compiled (method 2)! PropFirmBot.ex5 = ${EX5_SIZE} bytes"
            COMPILE_SUCCESS=true
        else
            echo "⚠️ Auto-compile failed"

            # Check compilation log for errors
            COMP_LOG="$EA_DEST/PropFirmBot.log"
            if [ -f "$COMP_LOG" ]; then
                echo "--- Compilation log ---"
                cat "$COMP_LOG" | tr -d '\0' | tail -30
                echo "--- End log ---"
            fi

            # Also check MQL5 logs directory
            for logf in "$MQL5_PATH/Logs/"*.log; do
                if [ -f "$logf" ]; then
                    MTIME=$(stat -c%Y "$logf" 2>/dev/null || echo 0)
                    NOW=$(date +%s)
                    AGE=$(( NOW - MTIME ))
                    if [ $AGE -lt 120 ]; then
                        echo "--- Recent MQL5 log: $(basename "$logf") ---"
                        cat "$logf" | tr -d '\0' | tail -20
                    fi
                fi
            done
        fi
    fi
else
    echo "❌ MetaEditor not found!"
    echo "Searching..."
    find "$MT5_PATH" -iname "metaeditor*" 2>/dev/null || echo "No MetaEditor anywhere in MT5 dir"
fi

#=== STEP 6: Start MT5 ===
echo ""
echo "━━━ [6/7] Starting MT5 ━━━"

# Make sure VNC is running
if ! pgrep -x "x11vnc" > /dev/null 2>&1; then
    echo "Starting VNC..."
    x11vnc -display :99 -forever -shared -rfbport 5900 -nopw -bg 2>/dev/null || true
    sleep 1
fi

# Start MT5 (fully detached so SSH doesn't hang)
echo "Starting MT5..."
nohup wine "$MT5_PATH/terminal64.exe" > /dev/null 2>&1 &
disown
echo "MT5 launch command sent"

# Wait for MT5 to start
echo "Waiting for MT5 to initialize (20s)..."
sleep 20

MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
if [ -n "$MT5_PID" ]; then
    echo "✅ MT5 is RUNNING (PID: $MT5_PID)"
else
    echo "⚠️ MT5 process not detected yet, waiting more (15s)..."
    sleep 15
    MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
    [ -n "$MT5_PID" ] && echo "✅ MT5 is RUNNING (PID: $MT5_PID)" || echo "❌ MT5 failed to start"
fi

#=== STEP 7: Install Watchdog ===
echo ""
echo "━━━ [7/7] Installing Watchdog ━━━"

mkdir -p "$SCRIPTS_DIR" "$LOGS_DIR" "$STATE_DIR"

# Create systemd services
cat > /etc/systemd/system/xvfb.service << 'SVC_EOF'
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
SVC_EOF

cat > /etc/systemd/system/mt5.service << SVC_EOF
[Unit]
Description=MetaTrader 5 Trading Terminal
After=network.target xvfb.service
Requires=xvfb.service

[Service]
Type=simple
User=root
Environment=DISPLAY=:99
Environment=WINEPREFIX=/root/.wine
ExecStart=/usr/bin/wine "$MT5_PATH/terminal64.exe"
Restart=always
RestartSec=30
StartLimitIntervalSec=600
StartLimitBurst=10

[Install]
WantedBy=multi-user.target
SVC_EOF

cat > /etc/systemd/system/x11vnc.service << 'SVC_EOF'
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
SVC_EOF

systemctl daemon-reload 2>/dev/null || true
systemctl enable xvfb.service mt5.service x11vnc.service 2>/dev/null || true
echo "✅ Systemd services configured"

# Create watchdog script
cat > "$SCRIPTS_DIR/watchdog.sh" << 'WDOG_EOF'
#!/bin/bash
TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
LOG_FILE="/root/PropFirmBot/logs/watchdog.log"
STATE_FILE="/root/PropFirmBot/state/mt5_status"
RESTART_COUNT_FILE="/root/PropFirmBot/state/restart_count"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
TIMESTAMP_SHORT=$(date '+%d/%m %H:%M')

mkdir -p /root/PropFirmBot/logs /root/PropFirmBot/state

send_telegram() {
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" -d "text=$1" -d "parse_mode=HTML" > /dev/null 2>&1 || true
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
    MIN=$(date '+%M')
    [ "$((MIN % 14))" -lt 2 ] && echo "$TIMESTAMP [OK] MT5 running (PID: $MT5_PID)" >> "$LOG_FILE"
else
    echo "$TIMESTAMP [ALERT] MT5 not running! Restarting..." >> "$LOG_FILE"
    systemctl restart mt5.service 2>/dev/null || true
    sleep 15
    NEW_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
    if [ -z "$NEW_PID" ]; then
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

MT5 was down - restarted!
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

[ "$(date '+%H')" = "00" ] && [ "$(date '+%M')" -lt 3 ] && echo "0" > "$RESTART_COUNT_FILE"
[ -f "$LOG_FILE" ] && tail -2000 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
WDOG_EOF

chmod +x "$SCRIPTS_DIR/watchdog.sh"

# Create daily report
cat > "$SCRIPTS_DIR/daily_report.sh" << 'RPT_EOF'
#!/bin/bash
TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
[ -n "$MT5_PID" ] && MT5_STATUS="RUNNING (PID: $MT5_PID)" || MT5_STATUS="NOT RUNNING!"
VNC_PID=$(pgrep -f "x11vnc" 2>/dev/null || true)
[ -n "$VNC_PID" ] && VNC_STATUS="RUNNING" || VNC_STATUS="NOT RUNNING"
RESTART_COUNT=0
[ -f "/root/PropFirmBot/state/restart_count" ] && RESTART_COUNT=$(cat /root/PropFirmBot/state/restart_count)
RECENT=$(grep -E "\[ALERT\]|\[ERROR\]|\[RECOVERED\]" /root/PropFirmBot/logs/watchdog.log 2>/dev/null | tail -5 || echo "No events")
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=<b>PropFirmBot - Daily Report</b>

$(date '+%d/%m/%Y %H:%M')

<b>MT5:</b> ${MT5_STATUS}
<b>VNC:</b> ${VNC_STATUS}
<b>CPU:</b> $(top -bn1 | grep 'Cpu(s)' | awk '{printf \"%.0f\", \$2}' 2>/dev/null || echo '?')%
<b>RAM:</b> $(free | awk '/Mem/{printf \"%.0f\", \$3/\$2*100}' 2>/dev/null || echo '?')%
<b>Disk:</b> $(df -h / | awk 'NR==2{print \$5}' 2>/dev/null || echo '?')
$(uptime -p 2>/dev/null)

<b>Restarts (24h):</b> ${RESTART_COUNT}

<b>Events:</b>
${RECENT}" \
    -d "parse_mode=HTML" > /dev/null 2>&1 || true
RPT_EOF

chmod +x "$SCRIPTS_DIR/daily_report.sh"

# Set up cron
CRON_TMP=$(mktemp)
crontab -l 2>/dev/null > "$CRON_TMP" || true
sed -i '/PropFirmBot/d' "$CRON_TMP"
echo "*/2 * * * * $SCRIPTS_DIR/watchdog.sh  # PropFirmBot watchdog" >> "$CRON_TMP"
echo "0 6 * * * $SCRIPTS_DIR/daily_report.sh  # PropFirmBot daily report" >> "$CRON_TMP"
crontab "$CRON_TMP"
rm "$CRON_TMP"
echo "✅ Watchdog cron installed (every 2 min)"

# Initialize state
MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
[ -n "$MT5_PID" ] && echo "up" > "$STATE_DIR/mt5_status" || echo "unknown" > "$STATE_DIR/mt5_status"
echo "0" > "$STATE_DIR/restart_count"

#=== FINAL STATUS ===
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   FINAL STATUS                                   ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# MT5 status
MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
[ -n "$MT5_PID" ] && echo "✅ MT5: RUNNING (PID: $MT5_PID)" || echo "❌ MT5: NOT RUNNING"

# VNC
VNC_PID=$(pgrep -x "x11vnc" 2>/dev/null || true)
[ -n "$VNC_PID" ] && echo "✅ VNC: RUNNING" || echo "❌ VNC: NOT RUNNING"

# EA compiled
if [ -f "$EA_DEST/PropFirmBot.ex5" ]; then
    EX5_SIZE=$(stat -c%s "$EA_DEST/PropFirmBot.ex5" 2>/dev/null)
    echo "✅ EA: COMPILED (${EX5_SIZE} bytes)"
else
    echo "❌ EA: NOT COMPILED"
fi

# Connections
CONNS=$(ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 ")
[ -n "$CONNS" ] && echo "✅ BROKER: Connected" || echo "⚠️ BROKER: Waiting for connection..."

# Cron
crontab -l 2>/dev/null | grep -q "PropFirmBot" && echo "✅ WATCHDOG: Active" || echo "❌ WATCHDOG: Not set"

# EA source count
SRC_COUNT=$(ls "$EA_DEST"/*.mq5 "$EA_DEST"/*.mqh 2>/dev/null | wc -l)
echo "   EA source files: $SRC_COUNT"

# Send Telegram report
COMPILE_STATUS="NOT COMPILED"
[ -f "$EA_DEST/PropFirmBot.ex5" ] && COMPILE_STATUS="COMPILED ($(stat -c%s "$EA_DEST/PropFirmBot.ex5" 2>/dev/null) bytes)"
MT5_STATUS="NOT RUNNING"
[ -n "$MT5_PID" ] && MT5_STATUS="RUNNING (PID: $MT5_PID)"

send_telegram "<b>PropFirmBot - FULL RESTORE COMPLETE</b>

<b>MT5:</b> ${MT5_STATUS}
<b>EA:</b> ${COMPILE_STATUS}
<b>Watchdog:</b> Active (every 2 min)
<b>VNC:</b> $([ -n "$VNC_PID" ] && echo 'Running' || echo 'Not running')

EA files: ${EA_COUNT}
Config files: ${CFG_COUNT}

$(date '+%d/%m/%Y %H:%M:%S UTC')"

echo ""
echo "━━━ Broker connection check ━━━"
CONNS2=$(ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 ")
if [ -n "$CONNS2" ]; then
    echo "✅ Outbound connections active:"
    echo "$CONNS2" | head -5
else
    echo "⚠️ No broker connections yet (MT5 may still be initializing)"
fi

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   RESTORE COMPLETE                               ║"
echo "╚══════════════════════════════════════════════════╝"
