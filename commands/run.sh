#!/bin/bash
# =============================================================
# Deploy latest code to VPS - pull master and update EA files
# =============================================================

echo "============================================"
echo "  Deploy Latest Code to VPS"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"
CONFIG_DIR="$MT5_DIR/MQL5/Files/PropFirmBot"
REPO_DIR="/root/MT5-PropFirm-Bot"

# 1. Update repo to latest master
echo "=== [1] Update repo ==="
cd "$REPO_DIR"
echo "Current branch: $(git rev-parse --abbrev-ref HEAD)"
echo "Current commit: $(git log --oneline -1)"
git fetch origin master 2>&1
git checkout master 2>&1
git pull origin master 2>&1
echo "Updated to: $(git log --oneline -1)"
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

# 4. Compile EA
echo "=== [4] Compile EA ==="
export DISPLAY=:99
export WINEPREFIX=/root/.wine
METAEDITOR="$MT5_DIR/metaeditor64.exe"
if [ -f "$METAEDITOR" ]; then
    wine "$METAEDITOR" /compile:"$EA_DIR/PropFirmBot.mq5" /log 2>&1
    sleep 5
    # Check compilation result
    if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
        echo "Compilation SUCCESS - .ex5 exists"
        ls -la "$EA_DIR/PropFirmBot.ex5"
    else
        echo "WARNING: .ex5 file not found after compilation"
    fi
else
    echo "MetaEditor not found at $METAEDITOR"
    echo "Checking for .ex5:"
    ls -la "$EA_DIR"/*.ex5 2>/dev/null || echo "No .ex5 found"
fi
echo ""

# 5. Restart MT5
echo "=== [5] Restart MT5 ==="
# Kill existing MT5
pkill -f terminal64.exe 2>/dev/null
sleep 3
echo "MT5 killed, waiting..."
sleep 2

# Start MT5
screen -dmS mt5 bash -c "export DISPLAY=:99 && export WINEPREFIX=/root/.wine && wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server 2>&1"
sleep 10

# Verify
if pgrep -f terminal64.exe > /dev/null; then
    echo "MT5 RESTARTED SUCCESSFULLY"
else
    echo "WARNING: MT5 may not have started"
fi
echo ""

# 6. Verify
echo "=== [6] Final status ==="
ps aux | grep -i "terminal64" | grep -v grep || echo "MT5 NOT RUNNING"
echo ""
echo "EA files:"
ls -la "$EA_DIR"/*.ex5 2>/dev/null
echo ""
echo "Repo state:"
cd "$REPO_DIR" && git log --oneline -3
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
