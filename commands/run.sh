#!/bin/bash
# =============================================================
# Deploy latest code - pull from correct branch
# =============================================================

echo "============================================"
echo "  Deploy Latest Code (Fixed Branch)"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"
CONFIG_DIR="$MT5_DIR/MQL5/Files/PropFirmBot"
REPO_DIR="/root/MT5-PropFirm-Bot"
BRANCH="claude/build-cfd-trading-bot-fl0ld"

# 1. Update repo
echo "=== [1] Update repo ==="
cd "$REPO_DIR"
echo "Before: $(git log --oneline -1)"
git fetch origin "$BRANCH" 2>&1
git checkout "$BRANCH" 2>&1
git reset --hard "origin/$BRANCH" 2>&1
echo "After: $(git log --oneline -1)"
echo ""

# 2. Copy EA files
echo "=== [2] Copy EA files ==="
mkdir -p "$EA_DIR"
cp -v "$REPO_DIR"/EA/*.mq5 "$EA_DIR/" 2>&1
cp -v "$REPO_DIR"/EA/*.mqh "$EA_DIR/" 2>&1
echo ""

# 3. Copy config files
echo "=== [3] Copy config files ==="
mkdir -p "$CONFIG_DIR"
cp -v "$REPO_DIR"/configs/*.json "$CONFIG_DIR/" 2>&1
echo ""

# 4. Try to compile EA
echo "=== [4] Compile EA ==="
export DISPLAY=:99
export WINEPREFIX=/root/.wine
# Try multiple possible MetaEditor locations
for ME_PATH in \
    "$MT5_DIR/metaeditor64.exe" \
    "$MT5_DIR/MetaEditor64.exe" \
    "/root/.wine/drive_c/Program Files/MetaTrader 5/metaeditor64.exe"; do
    if [ -f "$ME_PATH" ]; then
        echo "Found MetaEditor at: $ME_PATH"
        wine "$ME_PATH" /compile:"$EA_DIR/PropFirmBot.mq5" /log 2>&1
        sleep 8
        break
    fi
done
# Check for MetaEditor in MT5 dir
echo "Files in MT5 root:"
ls "$MT5_DIR"/meta* "$MT5_DIR"/Meta* 2>/dev/null || echo "No metaeditor found"
echo ""
echo "EA .ex5 status:"
ls -la "$EA_DIR"/*.ex5 2>/dev/null || echo "No .ex5 found"
echo ""

# 5. Restart MT5 to pick up new files
echo "=== [5] Restart MT5 ==="
pkill -f terminal64.exe 2>/dev/null
sleep 5
screen -dmS mt5 bash -c "export DISPLAY=:99 && export WINEPREFIX=/root/.wine && cd '$MT5_DIR' && wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server 2>&1"
sleep 15

if pgrep -f terminal64.exe > /dev/null; then
    echo "MT5 RESTARTED SUCCESSFULLY"
else
    echo "WARNING: MT5 may not have started"
fi
echo ""

# 6. Verify
echo "=== [6] Verification ==="
echo "Repo: $(git log --oneline -1)"
echo "Branch: $(git rev-parse --abbrev-ref HEAD)"
ps aux | grep terminal64 | grep -v grep | head -2
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
