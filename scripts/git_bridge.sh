#!/bin/bash
# Git Bridge - Listens for commands via git and pushes results back
# Runs on VPS as a background service
#
# How it works:
# 1. Every 60 seconds, pulls from git
# 2. Checks bridge/commands/ for .cmd files
# 3. Executes the matching action
# 4. Writes output to bridge/reports/
# 5. Removes the .cmd file, commits, and pushes

REPO_DIR="/root/MT5-PropFirm-Bot"
BRANCH="claude/bot-status-check-g8Wi9"
COMMANDS_DIR="$REPO_DIR/bridge/commands"
REPORTS_DIR="$REPO_DIR/bridge/reports"
SCRIPTS_DIR="$REPO_DIR/scripts"
POLL_INTERVAL=60  # seconds

# Telegram notification (optional)
TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT="7013213983"

send_telegram() {
    local msg="$1"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT}" \
        -d text="${msg}" \
        -d parse_mode="HTML" > /dev/null 2>&1
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Ensure directories exist
mkdir -p "$COMMANDS_DIR" "$REPORTS_DIR"

log "🚀 Git Bridge started on branch: $BRANCH"
log "📂 Watching: $COMMANDS_DIR"
log "⏱️  Poll interval: ${POLL_INTERVAL}s"
send_telegram "🤖 Git Bridge started - listening for commands"

cd "$REPO_DIR" || exit 1

# Make sure we're on the right branch
git fetch origin "$BRANCH" 2>/dev/null
if git rev-parse --verify "$BRANCH" > /dev/null 2>&1; then
    git checkout "$BRANCH" 2>/dev/null
else
    git checkout -b "$BRANCH" "origin/$BRANCH" 2>/dev/null
fi

while true; do
    # Pull latest changes
    git pull origin "$BRANCH" --rebase 2>/dev/null

    # Check for command files
    CMD_FILES=$(find "$COMMANDS_DIR" -name "*.cmd" -type f 2>/dev/null)

    if [ -n "$CMD_FILES" ]; then
        for CMD_FILE in $CMD_FILES; do
            CMD_NAME=$(basename "$CMD_FILE" .cmd)
            CMD_CONTENT=$(cat "$CMD_FILE" 2>/dev/null)
            TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
            REPORT_FILE="$REPORTS_DIR/${CMD_NAME}_${TIMESTAMP}.report"

            log "📩 Found command: $CMD_NAME"

            case "$CMD_NAME" in
                check_status|status)
                    log "Running: Bot status check..."
                    bash "$SCRIPTS_DIR/check_bot_status.sh" > "$REPORT_FILE" 2>&1
                    ;;
                restart_mt5|restart)
                    log "Running: MT5 restart..."
                    {
                        echo "=== MT5 RESTART $(date) ==="
                        # Kill existing
                        pkill -f terminal64 2>/dev/null
                        sleep 3
                        # Start MT5
                        export DISPLAY=:99
                        export WINEPREFIX=/root/.wine
                        wine64 "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" &
                        sleep 10
                        # Verify
                        if pgrep -f terminal64 > /dev/null 2>&1; then
                            echo "✅ MT5 restarted successfully"
                        else
                            echo "❌ MT5 failed to start"
                        fi
                    } > "$REPORT_FILE" 2>&1
                    ;;
                restart_vnc|vnc)
                    log "Running: VNC restart..."
                    {
                        echo "=== VNC RESTART $(date) ==="
                        pkill -f x11vnc 2>/dev/null
                        pkill -f Xvfb 2>/dev/null
                        sleep 2
                        Xvfb :99 -screen 0 1280x1024x24 &
                        sleep 1
                        x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw
                        sleep 2
                        if pgrep -f x11vnc > /dev/null 2>&1; then
                            echo "✅ VNC restarted on port 5900"
                        else
                            echo "❌ VNC failed to start"
                        fi
                    } > "$REPORT_FILE" 2>&1
                    ;;
                logs|ea_logs)
                    log "Running: Fetch EA logs..."
                    {
                        echo "=== EA LOGS $(date) ==="
                        LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs"
                        LATEST=$(find "$LOG_DIR" -name "*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
                        if [ -n "$LATEST" ]; then
                            echo "File: $LATEST"
                            cat "$LATEST" | tr -d '\0' | tail -50
                        else
                            echo "No EA logs found"
                        fi
                    } > "$REPORT_FILE" 2>&1
                    ;;
                terminal_logs)
                    log "Running: Fetch terminal logs..."
                    {
                        echo "=== TERMINAL LOGS $(date) ==="
                        TERM_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/logs"
                        LATEST=$(find "$TERM_LOG_DIR" -name "*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
                        if [ -n "$LATEST" ]; then
                            echo "File: $LATEST"
                            cat "$LATEST" | tr -d '\0' | tail -50
                        else
                            echo "No terminal logs found"
                        fi
                    } > "$REPORT_FILE" 2>&1
                    ;;
                deploy|update_ea)
                    log "Running: Deploy EA files..."
                    {
                        echo "=== DEPLOY EA $(date) ==="
                        EA_SRC="$REPO_DIR/EA"
                        EA_DST="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot"
                        mkdir -p "$EA_DST"
                        cp -v "$EA_SRC"/*.mq5 "$EA_DST/" 2>&1
                        cp -v "$EA_SRC"/*.mqh "$EA_DST/" 2>&1
                        echo "Files deployed. Need to recompile in MT5."
                    } > "$REPORT_FILE" 2>&1
                    ;;
                custom)
                    log "Running: Custom command..."
                    {
                        echo "=== CUSTOM COMMAND $(date) ==="
                        echo "Command: $CMD_CONTENT"
                        echo "--- Output ---"
                        eval "$CMD_CONTENT" 2>&1
                    } > "$REPORT_FILE" 2>&1
                    ;;
                *)
                    log "Unknown command: $CMD_NAME"
                    echo "Unknown command: $CMD_NAME" > "$REPORT_FILE"
                    ;;
            esac

            # Remove the command file (it's been processed)
            rm -f "$CMD_FILE"

            log "✅ Report written: $REPORT_FILE"

            # Commit and push results
            cd "$REPO_DIR"
            git add bridge/reports/ bridge/commands/
            git commit -m "📊 Report: ${CMD_NAME} @ $(date '+%Y-%m-%d %H:%M')"

            # Push with retry
            for i in 1 2 3 4; do
                if git push -u origin "$BRANCH" 2>/dev/null; then
                    log "📤 Pushed report to git"
                    send_telegram "📊 Command <b>${CMD_NAME}</b> completed - report pushed to git"
                    break
                fi
                WAIT=$((2 ** i))
                log "Push failed, retry in ${WAIT}s..."
                sleep $WAIT
            done
        done
    fi

    sleep "$POLL_INTERVAL"
done
