#!/bin/bash
# =============================================================
# Deploy updated EA code to VPS + Recompile + Restart
# =============================================================

echo "=============================================="
echo "  DEPLOY OPTIMIZED EA - $(date)"
echo "=============================================="

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"
FILES_DIR="$MT5_DIR/MQL5/Files/PropFirmBot"
REPO_DIR="/root/MT5-PropFirm-Bot"

# 1. Update repo on VPS
echo ""
echo "=== 1. UPDATING REPO ==="
cd "$REPO_DIR"
git fetch --all
# Checkout the branch with changes
git checkout claude/bot-server-connection-qmvC0 2>/dev/null || git checkout -b claude/bot-server-connection-qmvC0 origin/claude/bot-server-connection-qmvC0
git pull origin claude/bot-server-connection-qmvC0
echo "Branch: $(git branch --show-current)"
echo "Last commit: $(git log --oneline -1)"

# 2. Backup current EA files
echo ""
echo "=== 2. BACKING UP CURRENT FILES ==="
cp "$EA_DIR/PropFirmBot.ex5" "$EA_DIR/PropFirmBot.ex5.bak_$(date +%Y%m%d_%H%M)" 2>/dev/null
echo "Backup done"

# 3. Copy updated EA source files
echo ""
echo "=== 3. COPYING EA FILES ==="
cp -v "$REPO_DIR/EA/"*.mq5 "$EA_DIR/" 2>/dev/null
cp -v "$REPO_DIR/EA/"*.mqh "$EA_DIR/" 2>/dev/null
echo "EA files copied"

# 4. Copy updated config files
echo ""
echo "=== 4. COPYING CONFIG FILES ==="
cp -v "$REPO_DIR/configs/"*.json "$FILES_DIR/" 2>/dev/null
echo "Config files copied"

# 5. Compile the EA
echo ""
echo "=== 5. COMPILING EA ==="
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# Use metaeditor to compile
METAEDITOR="$MT5_DIR/metaeditor64.exe"
if [ -f "$METAEDITOR" ]; then
    wine64 "$METAEDITOR" /compile:"MQL5/Experts/PropFirmBot/PropFirmBot.mq5" /log:"compile.log" /inc:"$MT5_DIR/MQL5" 2>/dev/null
    sleep 5
    echo "Compile log:"
    cat "$MT5_DIR/compile.log" 2>/dev/null | tr -d '\0' | strings | tail -5

    # Check if .ex5 was updated
    echo ""
    echo "EX5 file:"
    ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
else
    echo "MetaEditor not found at: $METAEDITOR"
    ls "$MT5_DIR/"*.exe 2>/dev/null
fi

# 6. Restart MT5 to load new EA
echo ""
echo "=== 6. RESTARTING MT5 ==="
# Kill existing MT5
pkill -f terminal64 2>/dev/null
sleep 3

# Start MT5
wine64 "$MT5_DIR/terminal64.exe" /portable &
sleep 10

# Check if MT5 started
if pgrep -a terminal64 > /dev/null 2>&1; then
    echo "MT5 STARTED successfully"
else
    # Sometimes it shows as wine process
    if pgrep -a wine > /dev/null 2>&1; then
        echo "Wine processes running (MT5 may be starting)"
    else
        echo "WARNING: MT5 may not have started!"
    fi
fi

# 7. Verify changes
echo ""
echo "=== 7. VERIFICATION ==="
echo "EA files:"
ls -la "$EA_DIR/"*.mq5 "$EA_DIR/"*.mqh "$EA_DIR/"*.ex5 2>/dev/null | tail -15

echo ""
echo "Config files:"
ls -la "$FILES_DIR/"*.json 2>/dev/null

echo ""
echo "Key parameter check (from source):"
grep "InpMaxSpreadMajor\|InpMaxSpreadXAU\|InpMinRR\|InpMaxPositions\|InpTrailingActivation\|InpBEActivation\|InpTradeXAUUSD\|InpNewsBefore\|InpOBLookback\|InpFVGMinPoints" "$EA_DIR/PropFirmBot.mq5" 2>/dev/null | head -15

echo ""
echo "=============================================="
echo "  DEPLOY COMPLETE - $(date)"
echo "=============================================="
