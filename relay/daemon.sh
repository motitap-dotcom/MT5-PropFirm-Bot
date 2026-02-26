#!/bin/bash
# ============================================================
# PropFirmBot Relay Daemon
# GitHub-based remote command execution system
#
# How it works:
#   1. Claude pushes a command to relay/command.json
#   2. This daemon polls GitHub every 15 seconds
#   3. When a new command is detected, it executes it
#   4. Results are written to relay/result.json and pushed back
#   5. Claude reads the result via git pull
# ============================================================

REPO_DIR="/root/MT5-PropFirm-Bot"
COMMAND_FILE="$REPO_DIR/relay/command.json"
RESULT_FILE="$REPO_DIR/relay/result.json"
LOCK_FILE="/tmp/relay_daemon.lock"
LOG_FILE="/var/log/relay_daemon.log"
POLL_INTERVAL=15

# Prevent multiple instances
if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Daemon already running (PID $PID)"
        exit 1
    fi
fi
echo $$ > "$LOCK_FILE"

log() {
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $1" | tee -a "$LOG_FILE"
}

cleanup() {
    rm -f "$LOCK_FILE"
    log "Daemon stopped"
    exit 0
}
trap cleanup SIGTERM SIGINT

# Write initial status
write_result() {
    local status="$1"
    local output="$2"
    local cmd_id="$3"
    cat > "$RESULT_FILE" << JSONEOF
{
  "id": "$cmd_id",
  "status": "$status",
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "hostname": "$(hostname)",
  "output": $(echo "$output" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo "\"$output\"")
}
JSONEOF
}

push_result() {
    cd "$REPO_DIR"
    git add relay/result.json 2>/dev/null
    git commit -m "relay: result $(date -u '+%Y-%m-%d %H:%M UTC')" --no-verify 2>/dev/null

    # Retry push up to 4 times with exponential backoff
    for i in 1 2 3 4; do
        if git push origin HEAD 2>/dev/null; then
            log "Result pushed successfully"
            return 0
        fi
        WAIT=$((2 ** i))
        log "Push failed, retrying in ${WAIT}s..."
        sleep $WAIT
    done
    log "Push failed after 4 retries"
    return 1
}

LAST_CMD_ID=""

log "=== Relay Daemon Started ==="
log "Repo: $REPO_DIR"
log "Poll interval: ${POLL_INTERVAL}s"

# Write initial "ready" result
write_result "ready" "Relay daemon is running and waiting for commands" "init-$(date +%s)"
cd "$REPO_DIR"
git add relay/result.json 2>/dev/null
git commit -m "relay: daemon started $(date -u '+%Y-%m-%d %H:%M UTC')" --no-verify 2>/dev/null
git push origin HEAD 2>/dev/null

while true; do
    cd "$REPO_DIR"

    # Pull latest changes
    git fetch origin 2>/dev/null
    git reset --hard origin/$(git branch --show-current) 2>/dev/null

    # Check if command file exists and has content
    if [ -f "$COMMAND_FILE" ]; then
        # Read command
        CMD_ID=$(python3 -c "import json; d=json.load(open('$COMMAND_FILE')); print(d.get('id',''))" 2>/dev/null)
        CMD_TYPE=$(python3 -c "import json; d=json.load(open('$COMMAND_FILE')); print(d.get('type',''))" 2>/dev/null)
        CMD_COMMAND=$(python3 -c "import json; d=json.load(open('$COMMAND_FILE')); print(d.get('command',''))" 2>/dev/null)

        # Only execute if this is a new command
        if [ -n "$CMD_ID" ] && [ "$CMD_ID" != "$LAST_CMD_ID" ] && [ "$CMD_ID" != "none" ]; then
            LAST_CMD_ID="$CMD_ID"
            log "New command: id=$CMD_ID type=$CMD_TYPE"

            # Write "running" status
            write_result "running" "Executing command..." "$CMD_ID"

            case "$CMD_TYPE" in
                "shell")
                    # Execute shell command with timeout
                    log "Executing: $CMD_COMMAND"
                    OUTPUT=$(timeout 120 bash -c "$CMD_COMMAND" 2>&1)
                    EXIT_CODE=$?
                    if [ $EXIT_CODE -eq 0 ]; then
                        write_result "success" "$OUTPUT" "$CMD_ID"
                    else
                        write_result "error" "Exit code: $EXIT_CODE\n$OUTPUT" "$CMD_ID"
                    fi
                    ;;

                "deploy")
                    # Full deploy: pull + copy files + restart MT5
                    log "Running deploy..."
                    OUTPUT=""
                    OUTPUT+="=== Git Pull ===\n"
                    OUTPUT+=$(cd "$REPO_DIR" && git pull 2>&1)
                    OUTPUT+="\n\n=== Copy EA files ===\n"
                    OUTPUT+=$(cp -v "$REPO_DIR/EA/"* "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot/" 2>&1)
                    OUTPUT+="\n\n=== Copy configs ===\n"
                    OUTPUT+=$(cp -v "$REPO_DIR/configs/"* "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot/" 2>&1)
                    OUTPUT+="\n\n=== Restart MT5 ===\n"
                    export DISPLAY=:99 WINEPREFIX=/root/.wine WINEDEBUG=-all STAGING_WRITECOPY=1
                    killall -9 terminal64.exe 2>/dev/null
                    wineserver -k 2>/dev/null
                    sleep 5
                    cd "/root/.wine/drive_c/Program Files/MetaTrader 5"
                    wine terminal64.exe &
                    sleep 10
                    OUTPUT+="\n$(ps aux | grep terminal64 | grep -v grep)"
                    write_result "success" "$OUTPUT" "$CMD_ID"
                    ;;

                "status")
                    # Full status check
                    log "Running status check..."
                    OUTPUT=""
                    OUTPUT+="=== Wine ===\n$(wine --version 2>/dev/null)\n"
                    OUTPUT+="\n=== MT5 Process ===\n$(ps aux | grep terminal64 | grep -v grep 2>/dev/null || echo 'NOT RUNNING')\n"
                    OUTPUT+="\n=== VNC ===\n$(ps aux | grep x11vnc | grep -v grep 2>/dev/null || echo 'NOT RUNNING')\n"
                    OUTPUT+="\n=== EA .ex5 ===\n$(find '/root/.wine/drive_c/Program Files/MetaTrader 5' -name 'PropFirmBot.ex5' 2>/dev/null || echo 'NOT FOUND')\n"
                    OUTPUT+="\n=== Connections ===\n$(ss -tn state established 2>/dev/null | grep -v ':22 \|:5900 \|:53 ' | head -10)\n"
                    OUTPUT+="\n=== Latest EA Log ===\n"
                    EALOG=$(ls -t "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs/"*.log 2>/dev/null | head -1)
                    if [ -n "$EALOG" ]; then
                        OUTPUT+="File: $EALOG\n$(cat "$EALOG" | tr -d '\0' | tail -20)\n"
                    else
                        OUTPUT+="No EA logs\n"
                    fi
                    OUTPUT+="\n=== status.json ===\n$(cat '/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot/status.json' 2>/dev/null | head -20 || echo 'N/A')\n"
                    OUTPUT+="\n=== System ===\nCPU: $(top -bn1 | grep Cpu | head -1)\nMem: $(free -h | grep Mem)\nDisk: $(df -h / | tail -1)\n"
                    write_result "success" "$OUTPUT" "$CMD_ID"
                    ;;

                "restart-mt5")
                    log "Restarting MT5..."
                    export DISPLAY=:99 WINEPREFIX=/root/.wine WINEDEBUG=-all STAGING_WRITECOPY=1
                    killall -9 terminal64.exe 2>/dev/null
                    wineserver -k 2>/dev/null
                    sleep 5
                    cd "/root/.wine/drive_c/Program Files/MetaTrader 5"
                    wine terminal64.exe &
                    sleep 10
                    OUTPUT="MT5 restarted.\n$(ps aux | grep terminal64 | grep -v grep)"
                    write_result "success" "$OUTPUT" "$CMD_ID"
                    ;;

                "restart-vnc")
                    log "Restarting VNC..."
                    killall -9 x11vnc Xvfb 2>/dev/null
                    sleep 2
                    rm -f /tmp/.X99-lock /tmp/.X11-unix/X99 2>/dev/null
                    Xvfb :99 -screen 0 1280x1024x24 -ac +extension GLX +render -noreset &
                    sleep 3
                    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw -xkb 2>/dev/null
                    sleep 2
                    OUTPUT="VNC restarted.\nXvfb: $(pgrep -x Xvfb)\nx11vnc: $(pgrep -x x11vnc)"
                    write_result "success" "$OUTPUT" "$CMD_ID"
                    ;;

                "compile")
                    log "Compiling EA..."
                    export DISPLAY=:99 WINEPREFIX=/root/.wine WINEDEBUG=-all
                    cd "/root/.wine/drive_c/Program Files/MetaTrader 5"
                    wine metaeditor64.exe /compile:"MQL5\Experts\PropFirmBot\PropFirmBot.mq5" /log 2>/dev/null &
                    sleep 25
                    wineserver -w 2>/dev/null
                    sleep 3
                    sync
                    EX5=$(find "/root/.wine/drive_c/Program Files/MetaTrader 5" -name "PropFirmBot.ex5" 2>/dev/null | head -1)
                    if [ -n "$EX5" ]; then
                        OUTPUT="SUCCESS! Found: $EX5 ($(stat -c%s "$EX5") bytes)"
                    else
                        OUTPUT="FAILED - .ex5 not created\nLog:\n$(find "/root/.wine/drive_c/Program Files/MetaTrader 5" -name "*.log" -newer "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot/PropFirmBot.mq5" -exec tail -5 {} \; 2>/dev/null)"
                    fi
                    write_result "success" "$OUTPUT" "$CMD_ID"
                    ;;

                *)
                    write_result "error" "Unknown command type: $CMD_TYPE" "$CMD_ID"
                    ;;
            esac

            log "Command completed, pushing result..."
            push_result
        fi
    fi

    sleep $POLL_INTERVAL
done
