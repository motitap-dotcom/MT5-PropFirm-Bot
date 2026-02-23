#!/bin/bash
#=============================================================
# PropFirmBot Dashboard - Deployment Script
# Run on VPS: bash /root/MT5-PropFirm-Bot/dashboard/deploy.sh
#=============================================================

set -e

echo "=========================================="
echo "  PropFirmBot Dashboard - Deploy"
echo "=========================================="

# Paths
REPO_DIR="/root/MT5-PropFirm-Bot"
DASHBOARD_DIR="$REPO_DIR/dashboard"
MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"
MT5_FILES="$MT5_DIR/MQL5/Files"
PROPFIRMBOT_FILES="$MT5_FILES/PropFirmBot"

# 1. Create PropFirmBot files directory if needed
echo "[1/5] Creating directories..."
mkdir -p "$PROPFIRMBOT_FILES"

# 2. Copy StatusWriter.mqh to EA folder
echo "[2/5] Copying StatusWriter.mqh to EA folder..."
cp "$REPO_DIR/EA/StatusWriter.mqh" "$EA_DIR/StatusWriter.mqh"
echo "  -> Copied StatusWriter.mqh"

# 3. Copy updated PropFirmBot.mq5
echo "[3/5] Copying updated PropFirmBot.mq5..."
cp "$REPO_DIR/EA/PropFirmBot.mq5" "$EA_DIR/PropFirmBot.mq5"
echo "  -> Copied PropFirmBot.mq5"

# 4. Compile EA
echo "[4/5] Compiling EA..."
METAEDITOR="$MT5_DIR/MetaEditor64.exe"
EA_SOURCE="$EA_DIR/PropFirmBot.mq5"

if [ -f "$METAEDITOR" ]; then
    cd "$MT5_DIR"
    wine "$METAEDITOR" /compile:"$EA_SOURCE" /log 2>/dev/null
    sleep 3

    if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
        echo "  -> EA compiled successfully!"
        ls -la "$EA_DIR/PropFirmBot.ex5"
    else
        echo "  [!] Compilation may have failed - check MT5 logs"
    fi
else
    echo "  [!] MetaEditor not found - please compile manually in MT5"
fi

# 5. Start dashboard server
echo "[5/5] Starting dashboard server..."

# Kill existing dashboard if running
pkill -f "python3.*server.py" 2>/dev/null || true
sleep 1

# Start dashboard in background
cd "$DASHBOARD_DIR"
nohup python3 server.py 8081 > /tmp/dashboard.log 2>&1 &
DASH_PID=$!
sleep 2

# Check if running
if kill -0 $DASH_PID 2>/dev/null; then
    echo ""
    echo "=========================================="
    echo "  Dashboard is RUNNING!"
    echo "  URL: http://77.237.234.2:8081"
    echo "  PID: $DASH_PID"
    echo "  Log: /tmp/dashboard.log"
    echo "=========================================="
    echo ""
    echo "  IMPORTANT: Restart the EA in MT5 to"
    echo "  load the new StatusWriter module!"
    echo "  (Right-click EA -> Remove, then re-attach)"
    echo "=========================================="
else
    echo "  [!] Dashboard failed to start. Check logs:"
    cat /tmp/dashboard.log
fi
