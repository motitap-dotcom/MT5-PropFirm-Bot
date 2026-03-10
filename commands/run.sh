#!/bin/bash
# =============================================================
# Deploy PropFirmBot v4.0 - Strategy Redesign
# =============================================================
echo "============================================"
echo "  PropFirmBot v4.0 Deploy"
echo "  $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

REPO_DIR="/root/MT5-PropFirm-Bot"
BRANCH="claude/redesign-bot-strategy-woBVq"
MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
CONFIG_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"

# Step 1: Pull latest code
echo "=== [1] Pull latest code ==="
cd "$REPO_DIR" || { echo "ERROR: Repo not found"; exit 1; }
git fetch origin "$BRANCH" 2>&1
git checkout "$BRANCH" 2>&1 || git checkout -b "$BRANCH" "origin/$BRANCH" 2>&1
git pull origin "$BRANCH" 2>&1
echo "Commit: $(git log --oneline -1)"
echo ""

# Step 2: Copy EA files
echo "=== [2] Copy EA files ==="
mkdir -p "$EA_DIR" "$CONFIG_DIR"
for f in EA/*.mq5 EA/*.mqh; do
    [ -f "$f" ] && cp -v "$f" "$EA_DIR/"
done
echo ""

# Step 3: Copy config files
echo "=== [3] Copy config files ==="
for f in configs/*.json; do
    [ -f "$f" ] && cp -v "$f" "$CONFIG_DIR/"
done
echo ""

# Step 4: Compile EA
echo "=== [4] Compile EA ==="
cd "$EA_DIR"
WINEPREFIX=/root/.wine wine "${MT5_BASE}/metaeditor64.exe" /compile:PropFirmBot.mq5 /log 2>/dev/null || true
sleep 5
echo "Compiled files:"
ls -la *.ex5 2>/dev/null || echo "WARNING: No .ex5 files"
echo ""

# Step 5: Restart MT5
echo "=== [5] Restart MT5 ==="
pkill -f terminal64.exe 2>/dev/null || true
sleep 3

export DISPLAY=:99
export WINEPREFIX=/root/.wine

# Ensure Xvfb
if ! pgrep -x Xvfb > /dev/null; then
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
fi

# Ensure VNC
if ! pgrep -x x11vnc > /dev/null; then
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null || true
fi

# Start MT5
wine "${MT5_BASE}/terminal64.exe" &
sleep 10
echo ""

# Step 6: Verify
echo "=== [6] Verify ==="
echo "MT5 process:"
pgrep -a terminal64 || echo "WARNING: MT5 not running!"
echo ""
echo "EA .ex5 files:"
ls -la "${EA_DIR}/"*.ex5 2>/dev/null || echo "No compiled EA"
echo ""
echo "Config files:"
ls -la "${CONFIG_DIR}/"*.json 2>/dev/null
echo ""
echo "=== Deploy Complete $(date -u '+%H:%M:%S UTC') ==="
