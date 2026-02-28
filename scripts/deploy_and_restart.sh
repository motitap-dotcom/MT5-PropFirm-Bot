#!/bin/bash
# Deploy updated EA files to VPS and restart MT5
# Optimized for GitHub Actions (no hanging SSH)

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
REPO="/root/MT5-PropFirm-Bot"
NOW=$(date '+%Y-%m-%d %H:%M:%S UTC')

echo "============================================"
echo "  PropFirmBot - Deploy & Restart"
echo "  $NOW"
echo "============================================"

# 1. Update repo
echo ""
echo ">>> Updating repo..."
cd "$REPO"
git fetch --all 2>/dev/null || true
CURRENT=$(git branch --show-current)
echo "Current branch: $CURRENT"

# Try new branch first, then old branch
for branch in "claude/check-bot-status-1N9wR" "claude/build-cfd-trading-bot-fl0ld"; do
    if git checkout "$branch" 2>/dev/null; then
        git pull origin "$branch" 2>/dev/null || true
        echo "Updated branch: $branch"
        break
    fi
done
echo "Latest commit: $(git log --oneline -1)"

# 2. Copy ALL EA files
echo ""
echo ">>> Copying EA files..."
for f in "$REPO/EA/"*.mq5 "$REPO/EA/"*.mqh; do
    if [ -f "$f" ]; then
        cp "$f" "$EA_DIR/"
        echo "  Copied: $(basename $f)"
    fi
done

echo ""
echo "Files in EA directory:"
ls -la "$EA_DIR/" | grep -E "\.mq5|\.mqh|\.ex5"

# 3. Kill MT5
echo ""
echo ">>> Stopping MT5..."
pkill -f terminal64 2>/dev/null && echo "MT5 killed" || echo "MT5 was not running"
sleep 2

# 4. Ensure display is ready
export DISPLAY=:99
if ! pgrep -x Xvfb > /dev/null; then
    echo "Starting Xvfb..."
    nohup Xvfb :99 -screen 0 1280x1024x24 > /dev/null 2>&1 &
    sleep 2
fi
if ! pgrep -x x11vnc > /dev/null; then
    echo "Starting x11vnc..."
    nohup x11vnc -display :99 -forever -shared -rfbport 5900 -nopw > /dev/null 2>&1 &
    sleep 1
fi

# 5. Start MT5 (with nohup so SSH won't hang)
echo ""
echo ">>> Starting MT5..."
CONFIG="$MT5/config/startup.ini"
if [ -f "$CONFIG" ]; then
    nohup wine "$MT5/terminal64.exe" /config:"$CONFIG" > /dev/null 2>&1 &
else
    nohup wine "$MT5/terminal64.exe" > /dev/null 2>&1 &
fi
MT5_START_PID=$!
echo "MT5 started with PID: $MT5_START_PID"

# Wait a bit for MT5 to start
sleep 5

# 6. Quick verification
echo ""
echo ">>> Verification..."
MT5_RUNNING=$(ps aux | grep -i terminal64 | grep -v grep | wc -l)
echo "MT5 processes: $MT5_RUNNING"
if [ "$MT5_RUNNING" -gt 0 ]; then
    echo "MT5: RUNNING OK"
    ps aux | grep -i terminal64 | grep -v grep
else
    echo "MT5: NOT YET - may still be starting (Wine init takes time)"
fi

echo "Xvfb: $(pgrep -x Xvfb > /dev/null && echo 'RUNNING' || echo 'NOT RUNNING')"
echo "x11vnc: $(pgrep -x x11vnc > /dev/null && echo 'RUNNING' || echo 'NOT RUNNING')"

echo ""
echo ">>> EA .ex5 file (will be recompiled by MT5 on startup):"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo "Will compile on first load"

echo ""
echo ">>> Source files updated:"
ls -la "$EA_DIR/SignalEngine.mqh" "$EA_DIR/RiskManager.mqh" "$EA_DIR/PropFirmBot.mq5" 2>/dev/null

echo ""
echo "============================================"
echo "  Deploy Complete - $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "  MT5 will auto-compile EA on startup"
echo "  NOTE: EA needs to be re-attached to chart"
echo "  (or MT5 remembers from last session)"
echo "============================================"
