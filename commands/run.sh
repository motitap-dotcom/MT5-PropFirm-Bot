#!/bin/bash
# =============================================================
# DEPLOY UPDATED EA + RECOMPILE + RESTART + VERIFY
# =============================================================

echo "============================================"
echo "  DEPLOY & VERIFY - STRATEGY FIX"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"

# Step 1: Pull latest code
echo "=== STEP 1: Pull latest code ==="
cd /root/MT5-PropFirm-Bot
git fetch origin 2>&1
# Try to pull from current branch or the new fix branch
git pull 2>&1 || true
# Also try to get the specific branch
git checkout claude/bot-status-command-CfoXO 2>/dev/null && git pull origin claude/bot-status-command-CfoXO 2>&1 || true
echo ""

# Step 2: Copy EA files
echo "=== STEP 2: Copy EA files ==="
cp -v /root/MT5-PropFirm-Bot/EA/*.mq5 "$EA_DIR/" 2>&1
cp -v /root/MT5-PropFirm-Bot/EA/*.mqh "$EA_DIR/" 2>&1
echo ""

# Step 3: Verify key changes
echo "=== STEP 3: Verify changes applied ==="
echo "--- Strategy default (should be EMA_CROSS) ---"
grep "InpStrategy" "$EA_DIR/PropFirmBot.mq5" | head -1
echo ""
echo "--- XAUUSD Spread (should be 45.0) ---"
grep "InpMaxSpreadXAU" "$EA_DIR/PropFirmBot.mq5" | head -1
echo ""
echo "--- AutoBlockSymbol (should be false) ---"
grep "InpAutoBlockSymbol" "$EA_DIR/PropFirmBot.mq5" | head -1
echo ""
echo "--- RiskManager default XAU spread (should be 45.0) ---"
grep "m_max_spread_xau" "$EA_DIR/RiskManager.mqh" | head -2
echo ""
echo "--- Fallback logic (should try other strategy) ---"
grep -A2 "Fallback" "$EA_DIR/PropFirmBot.mq5" | head -5
echo ""

# Step 4: Stop MT5
echo "=== STEP 4: Stop MT5 ==="
pkill -f terminal64.exe 2>/dev/null
sleep 5
echo "MT5 stopped"
echo ""

# Step 5: Recompile
echo "=== STEP 5: Recompile EA ==="
export DISPLAY=:99

# Backup current .ex5
cp "$EA_DIR/PropFirmBot.ex5" "$EA_DIR/PropFirmBot.ex5.bak_$(date +%Y%m%d_%H%M)" 2>/dev/null

# Compile
WINEPREFIX=/root/.wine wine "${MT5_BASE}/metaeditor64.exe" /compile:"${EA_DIR}/PropFirmBot.mq5" /log 2>&1 || true
sleep 8

echo "Compiled file:"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>&1
echo ""

# Check compilation log
if [ -f "${EA_DIR}/PropFirmBot.log" ]; then
    echo "Compilation log:"
    cat "${EA_DIR}/PropFirmBot.log" 2>&1
    echo ""
fi

# Step 6: Start MT5
echo "=== STEP 6: Start MT5 ==="
export DISPLAY=:99
WINEPREFIX=/root/.wine wine "${MT5_BASE}/terminal64.exe" /portable &
sleep 15

if pgrep -f terminal64 > /dev/null 2>&1; then
    MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
    echo "MT5: STARTED (PID: $MT5_PID)"
    echo -900 > /proc/$MT5_PID/oom_score_adj 2>/dev/null
    echo "OOM protection applied"
else
    echo "MT5: FAILED TO START!"
fi
echo ""

# Step 7: Wait for EA to load and check logs
echo "=== STEP 7: Wait for EA to load ==="
sleep 20

echo "=== EA LOG (latest entries) ==="
LATEST_EA_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_EA_LOG" ]; then
    echo "Log file: $LATEST_EA_LOG"
    tail -40 "$LATEST_EA_LOG" 2>&1
fi
echo ""

echo "============================================"
echo "  DEPLOY COMPLETE"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
