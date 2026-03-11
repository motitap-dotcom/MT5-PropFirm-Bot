#!/bin/bash
# Manual deploy: pull latest repo code, copy EA files to MT5, recompile
echo "=== MANUAL DEPLOY $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
EA_FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"
REPO_DIR="/root/MT5-PropFirm-Bot"

# 1. Pull latest code from repo
echo "--- Step 1: Pull latest code ---"
cd "$REPO_DIR"
git fetch origin 2>&1
# Try to get the merged code from default branch
git pull origin claude/build-cfd-trading-bot-fl0ld 2>&1 || git pull 2>&1
echo "Latest commits:"
git log --oneline -3

# 2. Copy EA files
echo ""
echo "--- Step 2: Copy EA files to MT5 ---"
cp -v "$REPO_DIR/EA/"*.mq5 "$EA_DIR/" 2>&1
cp -v "$REPO_DIR/EA/"*.mqh "$EA_DIR/" 2>&1

# 3. Copy config files
echo ""
echo "--- Step 3: Copy config files ---"
cp -v "$REPO_DIR/configs/"*.json "$EA_FILES_DIR/" 2>&1

# 4. Verify new code is present
echo ""
echo "--- Step 4: Verify new code ---"
echo "NewsFilter.mqh:"
grep -c "ShouldClosePositions" "$EA_DIR/NewsFilter.mqh" 2>/dev/null && echo "  ShouldClosePositions: FOUND" || echo "  ShouldClosePositions: NOT FOUND"
echo "PropFirmBot.mq5:"
grep -c "InpNewsClosePos" "$EA_DIR/PropFirmBot.mq5" 2>/dev/null && echo "  InpNewsClosePos: FOUND" || echo "  InpNewsClosePos: NOT FOUND"
grep -c "NEWS PRE-CLOSE" "$EA_DIR/PropFirmBot.mq5" 2>/dev/null && echo "  NEWS PRE-CLOSE: FOUND" || echo "  NEWS PRE-CLOSE: NOT FOUND"

# 5. Compile EA
echo ""
echo "--- Step 5: Compile EA ---"
METAEDITOR="${MT5_BASE}/metaeditor64.exe"
if [ -f "$METAEDITOR" ]; then
    cd "$EA_DIR"
    wine64 "$METAEDITOR" /compile:"PropFirmBot.mq5" /log 2>&1
    sleep 5
    echo "Compile log:"
    cat "${EA_DIR}/PropFirmBot.log" 2>/dev/null || echo "No compile log found"
    echo ""
    echo "Compiled file:"
    ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
else
    echo "MetaEditor not found at: $METAEDITOR"
    ls -la "${MT5_BASE}/"metaeditor* 2>/dev/null
fi

echo ""
echo "=== DEPLOY COMPLETE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
echo "NOTE: MT5 needs to reload the EA for changes to take effect."
echo "The EA will auto-reload on next tick if the .ex5 changed."
