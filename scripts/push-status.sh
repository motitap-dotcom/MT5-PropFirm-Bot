#!/bin/bash
# push-status.sh
# Copies status.json from MT5 to git repo and pushes to GitHub
# Run by cron every 15 minutes

REPO="/root/MT5-PropFirm-Bot"
MT5_FILES="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot"
STATUS_SRC="${MT5_FILES}/status.json"
STATUS_DST="${REPO}/status/status.json"

# Check source file exists
if [ ! -f "${STATUS_SRC}" ]; then
    echo "[$(date)] status.json not found at: ${STATUS_SRC}"
    exit 1
fi

# Copy to repo
mkdir -p "${REPO}/status"
cp "${STATUS_SRC}" "${STATUS_DST}"

# Git push
cd "${REPO}" || exit 1

git add status/status.json

# Only commit if there are actual changes
if ! git diff --cached --quiet; then
    git commit -m "status: auto-update $(date '+%Y-%m-%d %H:%M')"
    git push -u origin HEAD
    echo "[$(date)] status.json pushed to GitHub"
else
    echo "[$(date)] No changes in status.json - skipping push"
fi
