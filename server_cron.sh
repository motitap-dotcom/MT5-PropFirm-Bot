#!/bin/bash
# server_cron.sh — Auto-heal bot, collect status, push to GitHub API.
# Installed by auto-merge-deploy workflow.
# */5 * * * * cd /root/MT5-PropFirm-Bot && bash server_cron.sh >> /var/log/futures-bot-cron.log 2>&1
set -u

BOT_DIR="${BOT_DIR:-/root/MT5-PropFirm-Bot}"
SERVICE="futures-bot"
STATUS_FILE="server_status.json"
BRANCH="main"

cd "$BOT_DIR" || { echo "[$(date)] FATAL: $BOT_DIR not found"; exit 1; }

# ── Log rotation: keep under 5MB ──
CRON_LOG="/var/log/futures-bot-cron.log"
if [ -f "$CRON_LOG" ]; then
    LOG_SIZE=$(stat -c%s "$CRON_LOG" 2>/dev/null || echo "0")
    if [ "$LOG_SIZE" -gt 5242880 ] 2>/dev/null; then
        tail -1000 "$CRON_LOG" > "${CRON_LOG}.tmp" && mv "${CRON_LOG}.tmp" "$CRON_LOG"
        echo "[$(date)] Cron log rotated (was ${LOG_SIZE} bytes)"
    fi
fi

# ── Source GH_PAT ──
if [ -z "${GH_PAT:-}" ] && [ -f "$BOT_DIR/.gh_pat" ]; then
    . "$BOT_DIR/.gh_pat" 2>/dev/null || true
fi

# Auto-detect repo from git remote
GITHUB_REPO="${GITHUB_REPO:-$(git remote get-url origin | sed -E 's|.*github\.com[:/]||; s|\.git$||')}"

# ── 1. Pull latest code ──
echo "[$(date)] Checking for updates on $BRANCH..."
CODE_UPDATED="false"
if git fetch origin "$BRANCH" 2>/dev/null; then
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse "origin/$BRANCH" 2>/dev/null || echo "$LOCAL")

    if [ "$LOCAL" != "$REMOTE" ]; then
        echo "[$(date)] New code found. Updating..."
        git reset --hard "origin/$BRANCH"
        echo "[$(date)] Now at: $(git log -1 --oneline)"
        CODE_UPDATED="true"

        pip3 install -r requirements.txt -q 2>&1 | tail -3 || true

        echo "[$(date)] Restarting bot..."
        systemctl restart "$SERVICE"
        sleep 5
    else
        echo "[$(date)] No changes."
    fi
else
    echo "[$(date)] Warning: git fetch failed. Skipping code update."
    LOCAL=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
fi

# ── 2. Auto-heal: restart bot if down ──
RESTART_LOG="$BOT_DIR/.restart_history"
if ! systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
    echo "$(date +%s)" >> "$RESTART_LOG" 2>/dev/null || true

    RECENT_RESTARTS=0
    CUTOFF=$(($(date +%s) - 1800))
    if [ -f "$RESTART_LOG" ]; then
        RECENT_RESTARTS=$(awk -v cutoff="$CUTOFF" '$1 > cutoff' "$RESTART_LOG" 2>/dev/null | wc -l)
        awk -v cutoff="$CUTOFF" '$1 > cutoff' "$RESTART_LOG" > "${RESTART_LOG}.tmp" 2>/dev/null && \
            mv "${RESTART_LOG}.tmp" "$RESTART_LOG" 2>/dev/null || true
    fi

    if [ "$RECENT_RESTARTS" -ge 5 ]; then
        # Crash loop — check if it's the known PYTHONPATH error and self-heal
        LAST_ERROR=$(journalctl -u "$SERVICE" --no-pager -n 5 2>/dev/null | grep -o "No module named.*" | head -1)
        if echo "$LAST_ERROR" | grep -q "No module named"; then
            echo "[$(date)] PYTHONPATH crash loop detected ('$LAST_ERROR') — self-healing service file..."
            chmod +x "$BOT_DIR/scripts/start_bot.sh" 2>/dev/null || true
            cat > /etc/systemd/system/${SERVICE}.service << SVCEOF
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=$BOT_DIR
ExecStart=/bin/bash $BOT_DIR/scripts/start_bot.sh
Restart=on-failure
RestartSec=30
Environment=PYTHONUNBUFFERED=1
Environment=PYTHONPATH=$BOT_DIR
EnvironmentFile=$BOT_DIR/.env

[Install]
WantedBy=multi-user.target
SVCEOF
            systemctl daemon-reload
            systemctl enable "$SERVICE" 2>/dev/null
            systemctl reset-failed "$SERVICE" 2>/dev/null
            systemctl restart "$SERVICE" 2>/dev/null
            sleep 5
            if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
                echo "[$(date)] Self-heal SUCCEEDED."
            else
                echo "[$(date)] Self-heal FAILED — manual intervention needed."
            fi
        else
            echo "[$(date)] CRASH LOOP: $RECENT_RESTARTS restarts in 30 min. Skipping."
        fi
    else
        echo "[$(date)] Bot is DOWN (restart #$RECENT_RESTARTS) — auto-restarting..."
        systemctl reset-failed "$SERVICE" 2>/dev/null
        systemctl restart "$SERVICE" 2>/dev/null
        sleep 5
        if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
            echo "[$(date)] Auto-restart SUCCEEDED."
        else
            echo "[$(date)] Auto-restart FAILED."
        fi
    fi
fi

# ── 3. Collect status ──
BOT_ACTIVE="false"
BOT_PID=""
BOT_UPTIME=""

if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
    BOT_ACTIVE="true"
    BOT_PID=$(systemctl show "$SERVICE" --property=MainPID --value 2>/dev/null || echo "")
    BOT_UPTIME=$(systemctl show "$SERVICE" --property=ActiveEnterTimestamp --value 2>/dev/null || echo "")
fi

LAST_LOG=$(journalctl -u "$SERVICE" --no-pager -n 5 2>/dev/null | tail -5 || echo "no logs")
DISK_USAGE=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}' || echo "unknown")
MEMORY=$(free -m 2>/dev/null | awk '/^Mem:/{printf "%dMB/%dMB (%.0f%%)", $3, $2, $3/$2*100}' || echo "unknown")

STATUS_JSON="{}"
[ -f "$BOT_DIR/status/status.json" ] && STATUS_JSON=$(cat "$BOT_DIR/status/status.json" 2>/dev/null || echo "{}")

cat > "$STATUS_FILE" <<STATUSEOF
{
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "server_time": "$(date '+%Y-%m-%d %H:%M:%S %Z')",
  "bot_active": $BOT_ACTIVE,
  "bot_pid": "$BOT_PID",
  "bot_uptime_since": "$BOT_UPTIME",
  "git_commit": "$(git log -1 --format='%h %s')",
  "git_branch": "$(git branch --show-current 2>/dev/null || echo 'detached')",
  "code_updated": $CODE_UPDATED,
  "disk_usage": "$DISK_USAGE",
  "memory": "$MEMORY",
  "last_log": $(echo "$LAST_LOG" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))" 2>/dev/null || echo '""'),
  "bot_status": $STATUS_JSON
}
STATUSEOF

echo "[$(date)] Status: bot_active=$BOT_ACTIVE, pid=$BOT_PID"

# ── 4. Push status to GitHub via API ──
if [ -z "${GH_PAT:-}" ]; then
    echo "[$(date)] No GH_PAT — status written locally only."
    exit 0
fi

COMMIT_MSG="bot-status: $(date -u '+%Y-%m-%d %H:%M UTC') | active=$BOT_ACTIVE"
API_URL="https://api.github.com/repos/$GITHUB_REPO/contents/$STATUS_FILE"

push_status() {
    local file_sha
    file_sha=$(curl -sf -H "Authorization: token $GH_PAT" \
      "${API_URL}?ref=${BRANCH}" 2>/dev/null | \
      python3 -c "import sys,json; print(json.load(sys.stdin).get('sha',''))" 2>/dev/null || echo "")

    local payload
    payload=$(STATUS_FILE="$STATUS_FILE" COMMIT_MSG="$COMMIT_MSG" FILE_SHA="$file_sha" BRANCH="$BRANCH" python3 << 'PYEOF'
import json, base64, os
with open(os.environ['STATUS_FILE'], 'rb') as f:
    content = base64.b64encode(f.read()).decode()
payload = {'message': os.environ['COMMIT_MSG'], 'content': content, 'branch': os.environ['BRANCH']}
sha = os.environ.get('FILE_SHA', '')
if sha:
    payload['sha'] = sha
print(json.dumps(payload))
PYEOF
    )

    curl -sf -X PUT \
      -H "Authorization: token $GH_PAT" \
      -H "Accept: application/vnd.github.v3+json" \
      -H "Content-Type: application/json" \
      "$API_URL" \
      -d "$payload" > /dev/null 2>&1
}

PUSH_OK="false"
for i in 1 2 3; do
    if push_status; then
        PUSH_OK="true"
        echo "[$(date)] Status pushed via API (attempt $i)."
        break
    else
        echo "[$(date)] API push attempt $i failed. Retrying..."
        sleep "$i"
    fi
done

[ "$PUSH_OK" = "false" ] && echo "[$(date)] Push failed after 3 attempts."
echo "[$(date)] Done."
