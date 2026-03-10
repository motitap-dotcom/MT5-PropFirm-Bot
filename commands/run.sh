#!/bin/bash
# =============================================================
# VERIFY DEPLOY + RECOMPILE + RESTART MT5
# =============================================================

echo "============================================"
echo "  VERIFY DEPLOY & RECOMPILE"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"

# Step 1: Pull latest code from repo
echo "=== STEP 1: Pull latest code ==="
cd /root/MT5-PropFirm-Bot && git pull origin claude/test-bot-server-YSFJI 2>&1 || git pull 2>&1
echo ""

# Step 2: Copy EA files
echo "=== STEP 2: Copy EA files to MT5 ==="
cp -v /root/MT5-PropFirm-Bot/EA/*.mq5 "$EA_DIR/" 2>&1
cp -v /root/MT5-PropFirm-Bot/EA/*.mqh "$EA_DIR/" 2>&1
echo ""

# Step 3: Check files were updated
echo "=== STEP 3: Verify files ==="
echo "Guardian.mqh CanTrade check:"
grep -n "CanTrade" "$EA_DIR/Guardian.mqh" 2>&1
echo ""
echo "PropFirmBot.mq5 XAUUSD spread:"
grep -n "MaxSpreadXAU" "$EA_DIR/PropFirmBot.mq5" 2>&1
echo ""

# Step 4: Recompile
echo "=== STEP 4: Recompile EA ==="
cd "$EA_DIR"

# Backup current .ex5
cp PropFirmBot.ex5 PropFirmBot.ex5.bak_$(date +%Y%m%d_%H%M) 2>/dev/null

# Compile using MetaEditor
export DISPLAY=:99
WINEPREFIX=/root/.wine wine "${MT5_BASE}/metaeditor64.exe" /compile:"${EA_DIR}/PropFirmBot.mq5" /log 2>&1 || true
sleep 5

echo ""
echo "Compiled file:"
ls -la PropFirmBot.ex5 2>&1
echo ""

# Check compilation log
if [ -f "${EA_DIR}/PropFirmBot.log" ]; then
    echo "Compilation log:"
    cat "${EA_DIR}/PropFirmBot.log" 2>&1
    echo ""
fi

# Step 5: Restart MT5 to load new EA
echo "=== STEP 5: Restart MT5 ==="
echo "Stopping MT5..."
pkill -f terminal64.exe 2>/dev/null
sleep 3

echo "Starting MT5..."
export DISPLAY=:99
WINEPREFIX=/root/.wine wine "${MT5_BASE}/terminal64.exe" /portable &
sleep 10

# Check if MT5 started
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "MT5: RESTARTED SUCCESSFULLY"
    MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
    echo "PID: $MT5_PID"

    # Protect from OOM
    echo -900 > /proc/$MT5_PID/oom_score_adj 2>/dev/null
    echo "OOM protection applied"
else
    echo "MT5: FAILED TO START!"
fi
echo ""

echo "============================================"
echo "  DEPLOY COMPLETE"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
