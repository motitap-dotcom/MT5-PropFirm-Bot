#!/bin/bash
# Fix VPS repo conflicts, copy clean EA files, find MetaEditor and compile
echo "=== FIX DEPLOY $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
EA_FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"
REPO_DIR="/root/MT5-PropFirm-Bot"

# 1. Fix repo - abort merge, reset to remote
echo "--- Step 1: Fix VPS repo ---"
cd "$REPO_DIR"
git merge --abort 2>&1 || true
git fetch origin claude/build-cfd-trading-bot-fl0ld 2>&1
git checkout -f claude/build-cfd-trading-bot-fl0ld 2>&1 || git checkout -B claude/build-cfd-trading-bot-fl0ld origin/claude/build-cfd-trading-bot-fl0ld 2>&1
git reset --hard origin/claude/build-cfd-trading-bot-fl0ld 2>&1
echo "Current HEAD:"
git log --oneline -3

# 2. Verify clean files (no conflict markers)
echo ""
echo "--- Step 2: Verify clean files ---"
if grep -l "<<<<<<" "$REPO_DIR/EA/"*.mq5 "$REPO_DIR/EA/"*.mqh 2>/dev/null; then
    echo "ERROR: Still has conflict markers!"
else
    echo "OK: No conflict markers in EA files"
fi

# 3. Copy EA files
echo ""
echo "--- Step 3: Copy EA files ---"
cp -v "$REPO_DIR/EA/"*.mq5 "$EA_DIR/" 2>&1
cp -v "$REPO_DIR/EA/"*.mqh "$EA_DIR/" 2>&1
cp -v "$REPO_DIR/configs/"*.json "$EA_FILES_DIR/" 2>&1

# 4. Verify new code
echo ""
echo "--- Step 4: Verify new code on MT5 ---"
grep -c "ShouldClosePositions" "$EA_DIR/NewsFilter.mqh" && echo "  ShouldClosePositions: OK"
grep -c "InpNewsClosePos" "$EA_DIR/PropFirmBot.mq5" && echo "  InpNewsClosePos: OK"
grep -c "NEWS PRE-CLOSE" "$EA_DIR/PropFirmBot.mq5" && echo "  NEWS PRE-CLOSE: OK"
echo "Conflict check in deployed files:"
grep -c "<<<<<<" "$EA_DIR/"*.mq5 "$EA_DIR/"*.mqh 2>/dev/null && echo "ERROR: Conflicts in deployed files!" || echo "OK: No conflicts"

# 5. Find MetaEditor
echo ""
echo "--- Step 5: Find and run MetaEditor ---"
METAEDITOR=$(find "/root/.wine" -name "metaeditor*.exe" -type f 2>/dev/null | head -1)
echo "MetaEditor found: $METAEDITOR"

if [ -n "$METAEDITOR" ]; then
    export DISPLAY=:99
    export WINEPREFIX=/root/.wine
    cd "$EA_DIR"
    wine64 "$METAEDITOR" /compile:"$EA_DIR/PropFirmBot.mq5" /log 2>&1
    sleep 8
    echo ""
    echo "Compile result:"
    cat "$EA_DIR/PropFirmBot.log" 2>/dev/null || echo "No compile log"
    echo ""
    echo "Compiled .ex5 file:"
    ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
else
    echo "MetaEditor not found anywhere!"
    find "/root/.wine" -name "*.exe" -path "*/MetaTrader*" 2>/dev/null | head -10
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
