#!/bin/bash
# Manual deploy + recompile EA - 2026-03-17
# Reason: deploy workflow didn't trigger on feature branch
echo "=== MANUAL EA DEPLOY $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
REPO="/root/MT5-PropFirm-Bot"

# STEP 1: Pull latest code from feature branch
echo "--- 1. Pull latest code ---"
cd "$REPO"
git fetch origin claude/check-status-update-pSQRq 2>&1
git checkout claude/check-status-update-pSQRq 2>&1 || git checkout -b claude/check-status-update-pSQRq origin/claude/check-status-update-pSQRq 2>&1
git pull origin claude/check-status-update-pSQRq 2>&1
echo "Current commit: $(git log --oneline -1)"

# STEP 2: Copy EA files
echo ""
echo "--- 2. Copy EA files ---"
mkdir -p "$EA_DIR"
cp -v "$REPO/EA/"*.mq5 "$EA_DIR/" 2>&1
cp -v "$REPO/EA/"*.mqh "$EA_DIR/" 2>&1

# STEP 3: Copy configs
echo ""
echo "--- 3. Copy configs ---"
cp -v "$REPO/configs/"*.json "$MT5/MQL5/Files/PropFirmBot/" 2>&1

# STEP 4: Compile EA
echo ""
echo "--- 4. Compile EA ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine
METAEDITOR="$MT5/metaeditor64.exe"
if [ -f "$METAEDITOR" ]; then
    cd "$MT5"
    wine metaeditor64.exe /compile:"MQL5/Experts/PropFirmBot/PropFirmBot.mq5" /log:"compile.log" 2>/dev/null
    sleep 10
    echo "Compile log:"
    cat "$MT5/compile.log" 2>/dev/null | tr -d '\0' || echo "(no compile log)"

    # Check if .ex5 was updated
    EX5="$EA_DIR/PropFirmBot.ex5"
    if [ -f "$EX5" ]; then
        echo "EX5 file: $(ls -la "$EX5")"
        echo "EX5 modified: $(stat -c '%y' "$EX5")"
    else
        echo "WARNING: No .ex5 file found!"
    fi
else
    echo "MetaEditor not found at: $METAEDITOR"
    ls "$MT5/"*.exe 2>/dev/null
fi

# STEP 5: Restart MT5
echo ""
echo "--- 5. Restart MT5 ---"
pkill -f terminal64 2>/dev/null
sleep 3
pkill -9 -f terminal64 2>/dev/null
wineserver -k 2>/dev/null
sleep 2
echo "MT5 stopped"

# Start MT5
export DISPLAY=:99
export WINEPREFIX=/root/.wine
cd "$MT5"
nohup wine terminal64.exe /portable > /tmp/mt5_wine.log 2>&1 &
disown
echo "MT5 starting..."

# STEP 6: Wait and verify
sleep 20
echo ""
echo "--- 6. Verify ---"
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "MT5: RUNNING"
else
    echo "MT5: NOT RUNNING!"
fi

# Check latest log for new RiskMgr init line
LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "Latest log: $(basename "$LATEST_LOG")"
    echo ""
    echo "--- Init lines ---"
    cat "$LATEST_LOG" | tr -d '\0' | grep -E "RiskMgr|GUARDIAN|INIT|DD_Mode|HWM|TRAILING" | tail -20
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
