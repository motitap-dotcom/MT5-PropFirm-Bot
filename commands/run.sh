#!/bin/bash
# ===========================================================
# FULL DEPLOY: Stop MT5 → Pull → Copy → Compile → Verify → Start
# Key fix: MT5 must be STOPPED before compile, otherwise .ex5 is locked!
# ===========================================================

echo "============================================"
echo "  FULL DEPLOY + COMPILE"
echo "  $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

REPO="/root/MT5-PropFirm-Bot"
BRANCH="claude/check-update-compile-UvvFk"
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA="${MT5}/MQL5/Experts/PropFirmBot"
CFG="${MT5}/MQL5/Files/PropFirmBot"

# ==========================================
# STEP 1: STOP MT5 FIRST (so .ex5 is unlocked!)
# ==========================================
echo "=== [1] STOPPING MT5 ==="
pkill -f terminal64.exe 2>/dev/null
sleep 3
# Force kill if still running
pkill -9 -f terminal64.exe 2>/dev/null
sleep 1
if pgrep -f terminal64.exe >/dev/null 2>&1; then
    echo "ERROR: MT5 still running after kill!"
    pkill -9 -f terminal64 2>/dev/null
    sleep 2
fi
echo "MT5 stopped: $(pgrep -f terminal64.exe >/dev/null 2>&1 && echo 'STILL RUNNING!' || echo 'OK - stopped')"
echo ""

# ==========================================
# STEP 2: Record old .ex5 timestamp for comparison
# ==========================================
echo "=== [2] Old .ex5 timestamp ==="
OLD_EX5_DATE=$(stat -c %Y "$EA/PropFirmBot.ex5" 2>/dev/null || echo "0")
ls -la "$EA/PropFirmBot.ex5" 2>/dev/null || echo "No .ex5 file found"
echo ""

# ==========================================
# STEP 3: Pull latest code
# ==========================================
echo "=== [3] Pull latest code ==="
cd "$REPO"
git fetch origin "$BRANCH" 2>&1
git checkout "$BRANCH" 2>&1
git reset --hard "origin/$BRANCH" 2>&1
echo "Current commit: $(git log --oneline -1)"
echo ""

# ==========================================
# STEP 4: Copy EA files to MT5 directory
# ==========================================
echo "=== [4] Copy EA + config files ==="
mkdir -p "$EA" "$CFG"
cp -v "$REPO"/EA/*.mq5 "$EA/" 2>&1
cp -v "$REPO"/EA/*.mqh "$EA/" 2>&1
cp -v "$REPO"/configs/*.json "$CFG/" 2>&1
echo ""

# ==========================================
# STEP 5: Delete old .ex5 to force fresh compile
# ==========================================
echo "=== [5] Delete old .ex5 ==="
rm -f "$EA/PropFirmBot.ex5"
ls -la "$EA/PropFirmBot.ex5" 2>/dev/null && echo "ERROR: Could not delete!" || echo "Old .ex5 deleted OK"
echo ""

# ==========================================
# STEP 6: Compile with MetaEditor
# ==========================================
echo "=== [6] Compiling PropFirmBot.mq5 ==="
cd "$EA"
export DISPLAY=:99 WINEPREFIX=/root/.wine

# Make sure Xvfb is running (MetaEditor needs a display)
pgrep Xvfb >/dev/null || (Xvfb :99 -screen 0 1280x1024x24 &>/dev/null & sleep 2)

# Run MetaEditor compiler
wine "${MT5}/metaeditor64.exe" /compile:"MQL5\Experts\PropFirmBot\PropFirmBot.mq5" /log 2>/dev/null
COMPILE_EXIT=$?
echo "MetaEditor exit code: $COMPILE_EXIT"

# Wait for compilation to finish writing
sleep 5

# Also try with cd-relative path if first didn't work
if [ ! -f "$EA/PropFirmBot.ex5" ]; then
    echo "First compile attempt didn't produce .ex5, trying alternative path..."
    cd "${MT5}"
    wine "${MT5}/metaeditor64.exe" /compile:"MQL5\Experts\PropFirmBot\PropFirmBot.mq5" /log 2>/dev/null
    sleep 5
fi
echo ""

# ==========================================
# STEP 7: Verify compilation
# ==========================================
echo "=== [7] Compilation result ==="
if [ -f "$EA/PropFirmBot.ex5" ]; then
    NEW_EX5_DATE=$(stat -c %Y "$EA/PropFirmBot.ex5" 2>/dev/null || echo "0")
    ls -la "$EA/PropFirmBot.ex5"
    if [ "$NEW_EX5_DATE" != "$OLD_EX5_DATE" ] && [ "$NEW_EX5_DATE" != "0" ]; then
        echo "*** COMPILATION SUCCESS - .ex5 file is NEW! ***"
    else
        echo "WARNING: .ex5 exists but timestamp didn't change"
    fi
else
    echo "*** COMPILATION FAILED - NO .ex5 FILE! ***"
    echo ""
    echo "Searching for .ex5 anywhere in MT5 folder:"
    find "${MT5}" -name "PropFirmBot.ex5" -ls 2>/dev/null
fi

# Show compile log
echo ""
echo "=== Compilation log ==="
# MetaEditor writes log as UTF-16LE, convert to readable
for logfile in "$EA/PropFirmBot.log" "${MT5}/MQL5/Experts/PropFirmBot/PropFirmBot.log" "${MT5}/PropFirmBot.log"; do
    if [ -f "$logfile" ]; then
        echo "Log found at: $logfile"
        iconv -f UTF-16LE -t UTF-8 "$logfile" 2>/dev/null || cat "$logfile" 2>/dev/null
        break
    fi
done
echo ""

# ==========================================
# STEP 8: Start MT5
# ==========================================
echo "=== [8] Starting MT5 ==="
export DISPLAY=:99 WINEPREFIX=/root/.wine

# Ensure VNC is running
pgrep x11vnc >/dev/null || nohup x11vnc -display :99 -forever -shared -rfbport 5900 -nopw >/dev/null 2>&1 &

# Start MT5
nohup setsid wine "${MT5}/terminal64.exe" >/dev/null 2>&1 &
disown -a
sleep 8

# ==========================================
# STEP 9: Final verification
# ==========================================
echo "=== [9] Final status ==="
if pgrep -f terminal64.exe >/dev/null 2>&1; then
    echo "MT5: RUNNING (PID $(pgrep -f terminal64.exe | head -1))"
else
    echo "MT5: NOT RUNNING!"
fi

echo ""
echo ".ex5 file:"
ls -la "$EA/PropFirmBot.ex5" 2>/dev/null || echo "NOT FOUND!"

echo ""
echo "EA log (last 10 lines):"
EA_LOG_DIR="${MT5}/MQL5/Logs"
LATEST_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    tail -10 "$LATEST_LOG" 2>/dev/null
else
    echo "No EA logs found"
fi

echo ""
echo "============================================"
echo "  DEPLOY COMPLETE $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
