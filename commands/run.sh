#!/bin/bash
# =============================================================
# Sync repo to VPS + Recompile EA + Restart MT5
# Date: 2026-03-10
# Purpose: Ensure VPS runs the latest compiled version from repo
# =============================================================

echo "============================================"
echo "  SYNC & RECOMPILE PropFirmBot EA"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
CONFIG_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"
REPO_DIR="/root/MT5-PropFirm-Bot"

# --- Step 1: Pull latest code from repo ---
echo "=== [1/6] Pull latest code from GitHub ==="
cd "$REPO_DIR"
BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $BRANCH"
git fetch origin "$BRANCH" 2>&1
git reset --hard "origin/$BRANCH" 2>&1
echo "Latest commit: $(git log --oneline -1)"
echo ""

# --- Step 2: Show current .ex5 before update ---
echo "=== [2/6] Current .ex5 file (BEFORE recompile) ==="
ls -la "${EA_DIR}/"*.ex5 2>/dev/null || echo "No .ex5 files found"
echo ""

# --- Step 3: Copy EA source files ---
echo "=== [3/6] Copy EA source files to MT5 ==="
mkdir -p "$EA_DIR" "$CONFIG_DIR"

cp -v "$REPO_DIR/EA/"*.mq5 "$EA_DIR/" 2>&1
cp -v "$REPO_DIR/EA/"*.mqh "$EA_DIR/" 2>&1
echo ""

# --- Step 4: Copy config files ---
echo "=== [4/6] Copy config files to MT5 ==="
cp -v "$REPO_DIR/configs/"*.json "$CONFIG_DIR/" 2>&1
echo ""

# --- Step 5: Stop MT5, compile, restart ---
echo "=== [5/6] Stop MT5 + Compile EA ==="

# Kill running MT5
echo "Stopping MT5..."
pkill -f terminal64.exe 2>/dev/null || true
pkill -f metatrader 2>/dev/null || true
sleep 3

# Verify MT5 stopped
if pgrep -f terminal64.exe > /dev/null 2>&1; then
    echo "WARNING: MT5 still running, force killing..."
    pkill -9 -f terminal64.exe 2>/dev/null || true
    sleep 2
fi
echo "MT5 stopped."

# Compile with MetaEditor
echo ""
echo "Compiling PropFirmBot.mq5 with MetaEditor..."
cd "$EA_DIR"
DISPLAY=:99 WINEPREFIX=/root/.wine wine "${MT5_BASE}/metaeditor64.exe" /compile:"${EA_DIR}/PropFirmBot.mq5" /log 2>/dev/null
COMPILE_EXIT=$?
echo "MetaEditor exit code: $COMPILE_EXIT"

# Wait for compilation to finish
sleep 5

# Check compilation result
echo ""
echo "Compilation result:"
ls -la "${EA_DIR}/"*.ex5 2>/dev/null || echo "ERROR: No .ex5 files found after compilation!"

# Check for compile log
if [ -f "${EA_DIR}/PropFirmBot.log" ]; then
    echo ""
    echo "Compile log:"
    cat "${EA_DIR}/PropFirmBot.log" 2>/dev/null
fi

# Also check MetaEditor log location
ME_LOG="${MT5_BASE}/MQL5/Logs"
if [ -d "$ME_LOG" ]; then
    echo ""
    echo "MetaEditor logs (last modified):"
    ls -lt "$ME_LOG/"*.log 2>/dev/null | head -3
    LATEST_LOG=$(ls -t "$ME_LOG/"*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        echo "--- Last 20 lines of $LATEST_LOG ---"
        tail -20 "$LATEST_LOG" 2>/dev/null
    fi
fi

echo ""

# --- Step 6: Restart MT5 ---
echo "=== [6/6] Restart MT5 ==="
echo "Starting MT5..."
DISPLAY=:99 WINEPREFIX=/root/.wine wine "${MT5_BASE}/terminal64.exe" /portable &
MT5_PID=$!
echo "MT5 started with PID: $MT5_PID"

# Wait and verify
sleep 8

if pgrep -f terminal64.exe > /dev/null 2>&1; then
    echo "MT5 is RUNNING"
else
    echo "WARNING: MT5 may not have started properly"
fi

echo ""
echo "=== [DONE] .ex5 file after recompile ==="
ls -la "${EA_DIR}/"*.ex5 2>/dev/null
echo ""
echo "============================================"
echo "  SYNC & RECOMPILE COMPLETE"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
