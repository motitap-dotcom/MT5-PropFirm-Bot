#!/bin/bash
# =============================================================
# Fix #21: Clean restart with new compiled EA
# Problem: Old EA instance created AccountState.dat before new compile
# Solution: Kill ALL, delete state, start fresh with new .ex5
# =============================================================

echo "=== FIX #21 - $(date) ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine
export WINEDEBUG=-all

# ============================================
# STEP 1: Kill EVERYTHING
# ============================================
echo "--- STEP 1: Kill everything ---"
killall -9 terminal64.exe metaeditor64.exe 2>/dev/null
sleep 2
pkill -9 wineserver 2>/dev/null
sleep 5
echo "All wine processes killed"
echo ""

# ============================================
# STEP 2: Delete ALL AccountState.dat files
# ============================================
echo "--- STEP 2: Delete state files ---"
echo "Finding all AccountState files..."
find /root/.wine -name "*AccountState*" 2>/dev/null -exec rm -v {} \;
echo "Done"
echo ""

# ============================================
# STEP 3: Verify .ex5 is the new version
# ============================================
echo "--- STEP 3: Verify .ex5 ---"
ls -la "${MT5_BASE}/MQL5/Experts/PropFirmBot/PropFirmBot.ex5"
echo ""

# Quick check: grep the source to confirm our change is there
echo "Source code verification:"
grep "m_risk_multiplier.*=.*1.0" "${MT5_BASE}/MQL5/Experts/PropFirmBot/AccountStateManager.mqh" || echo "NOT FOUND in deployed source!"
grep "m_max_positions.*=.*3" "${MT5_BASE}/MQL5/Experts/PropFirmBot/AccountStateManager.mqh" || echo "NOT FOUND in deployed source!"
echo ""

# ============================================
# STEP 4: Ensure VNC running
# ============================================
echo "--- STEP 4: VNC ---"
if ! pgrep -x Xvfb > /dev/null; then
    rm -f /tmp/.X99-lock /tmp/.X11-unix/X99 2>/dev/null
    Xvfb :99 -screen 0 1280x1024x24 -ac +extension GLX +render -noreset &
    sleep 3
fi
if ! pgrep -x x11vnc > /dev/null; then
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw -xkb 2>/dev/null
    sleep 2
fi
echo "Xvfb: $(pgrep -x Xvfb)"
echo "x11vnc: $(pgrep -x x11vnc)"
echo ""

# ============================================
# STEP 5: Start MT5 with /config
# ============================================
echo "--- STEP 5: Start MT5 ---"
cd "$MT5_BASE"
DISPLAY=:99 nohup wine terminal64.exe "/config:config\\startup.ini" >/dev/null 2>&1 &
echo "Waiting 50 seconds for full initialization..."
sleep 50

if pgrep -f terminal64 > /dev/null; then
    echo "MT5 is RUNNING"
else
    echo "MT5 FAILED"
    # Try without config
    DISPLAY=:99 nohup wine terminal64.exe >/dev/null 2>&1 &
    sleep 30
fi
echo ""

# ============================================
# STEP 6: Check results
# ============================================
echo "--- STEP 6: Results ---"

TERM_LOG=$(ls -t "${MT5_BASE}/logs/"*.log 2>/dev/null | head -1)
echo "Terminal log (recent):"
iconv -f UTF-16LE -t UTF-8 "$TERM_LOG" 2>/dev/null | tail -10
echo ""

echo "Expert entries:"
iconv -f UTF-16LE -t UTF-8 "$TERM_LOG" 2>/dev/null | grep -i "expert\|startup\|config" | tail -10
echo ""

EA_LOG="${MT5_BASE}/MQL5/Logs/20260305.log"
if [ -f "$EA_LOG" ]; then
    echo "=== EA LOG ==="
    iconv -f UTF-16LE -t UTF-8 "$EA_LOG" 2>/dev/null | grep -E "13:(09|1[0-9]|2[0-9])" | head -30
    echo ""
    echo "=== KEY PARAMETERS ==="
    iconv -f UTF-16LE -t UTF-8 "$EA_LOG" 2>/dev/null | grep -i "risk\|multi\|max.*pos\|funded\|phase\|account\|ALL SYSTEMS\|Guardian\|multiplier" | tail -15
else
    echo "NO EA LOG"
fi
echo ""

# Start telegram relay if not running
pgrep -f telegram_relay > /dev/null || ([ -f /root/telegram_relay.sh ] && nohup bash /root/telegram_relay.sh > /root/telegram_relay.log 2>&1 &)

echo "=== DONE - $(date) ==="
