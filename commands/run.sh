#!/bin/bash
# Deploy latest EA from repo to VPS + restart MT5
echo "=== DEPLOY & RESTART $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

export DISPLAY=:99
MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"
CONFIG_DIR="$MT5_DIR/MQL5/Files/PropFirmBot"
REPO_DIR="/root/MT5-PropFirm-Bot"

# 1. Pull latest from repo
echo "[1] Pulling latest code..."
cd "$REPO_DIR"
git fetch origin claude/update-bot-deployment-Ej25j 2>&1 || git fetch origin 2>&1
git checkout claude/update-bot-deployment-Ej25j 2>/dev/null || true
git pull origin claude/update-bot-deployment-Ej25j 2>&1 || git pull 2>&1
echo "Git pull done"

# 2. Copy EA files
echo ""
echo "[2] Copying EA files..."
mkdir -p "$EA_DIR" "$CONFIG_DIR"
cp -v "$REPO_DIR"/EA/*.mq5 "$EA_DIR/" 2>&1
cp -v "$REPO_DIR"/EA/*.mqh "$EA_DIR/" 2>&1
echo ""
echo "[2b] Copying configs..."
cp -v "$REPO_DIR"/configs/*.json "$CONFIG_DIR/" 2>&1

# 3. Check version
echo ""
echo "[3] EA version on VPS:"
grep "property version" "$EA_DIR/PropFirmBot.mq5" 2>/dev/null

# 4. Try to compile
echo ""
echo "[4] Compiling EA..."
cd "$EA_DIR"
if [ -f "$MT5_DIR/metaeditor64.exe" ]; then
    WINEPREFIX=/root/.wine wine "$MT5_DIR/metaeditor64.exe" /compile:PropFirmBot.mq5 /log 2>/dev/null
    sleep 5
    ls -la PropFirmBot.ex5 2>/dev/null
else
    echo "MetaEditor not found, checking for existing .ex5..."
    ls -la PropFirmBot.ex5 2>/dev/null || echo "No .ex5 file"
fi

# 5. Restart MT5
echo ""
echo "[5] Restarting MT5..."
pkill -9 -f terminal64 2>/dev/null
sleep 3

# Ensure display
pgrep -x Xvfb > /dev/null || { Xvfb :99 -screen 0 1280x1024x24 & sleep 2; }
pgrep -x x11vnc > /dev/null || { x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null; sleep 1; }

cd "$MT5_DIR"
nohup wine "$MT5_DIR/terminal64.exe" /portable > /tmp/mt5_start.log 2>&1 &
echo "MT5 started (PID: $!)"
sleep 15

# 6. Verify
echo ""
echo "[6] Verification:"
pgrep -af terminal64 2>/dev/null && echo "MT5: RUNNING" || echo "MT5: NOT RUNNING!"

echo ""
echo "=== DEPLOY COMPLETE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
