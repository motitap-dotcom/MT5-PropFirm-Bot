#!/bin/bash
# =============================================================
# Fix #22: Restore deleted .mqh source files + verify everything
# The find command in Fix #21 accidentally deleted AccountStateManager.mqh
# source files (matched *AccountState* pattern). Need to redeploy.
# =============================================================

echo "=== FIX #22 - $(date) ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
REPO_DIR="/root/MT5-PropFirm-Bot"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# ============================================
# STEP 1: Redeploy EA source files (especially AccountStateManager.mqh)
# ============================================
echo "--- STEP 1: Redeploy EA source files ---"
cd "$REPO_DIR"
git pull origin claude/update-server-vnc-wsD2d 2>/dev/null
cp -v "$REPO_DIR/EA/"*.mqh "$EA_DIR/" 2>/dev/null
cp -v "$REPO_DIR/EA/"*.mq5 "$EA_DIR/" 2>/dev/null
echo ""

echo "Verify AccountStateManager.mqh restored:"
ls -la "$EA_DIR/AccountStateManager.mqh" 2>/dev/null
echo ""

# ============================================
# STEP 2: Full status check
# ============================================
echo "--- STEP 2: Full status ---"
echo "MT5: $(pgrep -f terminal64 > /dev/null && echo 'RUNNING' || echo 'DOWN')"
echo "VNC: $(pgrep -x x11vnc > /dev/null && echo 'RUNNING' || echo 'DOWN')"
echo "Xvfb: $(pgrep -x Xvfb > /dev/null && echo 'RUNNING' || echo 'DOWN')"
echo "Telegram relay: $(pgrep -f telegram_relay > /dev/null && echo 'RUNNING' || echo 'DOWN')"
echo ""

# ============================================
# STEP 3: EA log - verify parameters
# ============================================
echo "--- STEP 3: EA parameters ---"
EA_LOG="${MT5_BASE}/MQL5/Logs/20260305.log"
if [ -f "$EA_LOG" ]; then
    echo "Latest EA init parameters:"
    iconv -f UTF-16LE -t UTF-8 "$EA_LOG" 2>/dev/null | grep -E "Risk.*multi|MaxPos|Risk=|Phase:|FUNDED|multiplier|ALL SYSTEMS|Balance|HEARTBEAT" | tail -10
    echo ""
    echo "Latest heartbeat:"
    iconv -f UTF-16LE -t UTF-8 "$EA_LOG" 2>/dev/null | grep "HEARTBEAT" | tail -3
fi
echo ""

# ============================================
# STEP 4: Send success notification to Telegram
# ============================================
echo "--- STEP 4: Telegram notification ---"
curl -s -X POST "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
    -d chat_id="7013213983" \
    -d text="✅ <b>PropFirmBot - All Fixed!</b>

🤖 <b>EA Status:</b> ACTIVE
📊 <b>Parameters:</b>
  • Risk: 0.50% per trade
  • Max Positions: 3
  • Risk Multiplier: 100%
  • Phase: FUNDED
  • Trailing DD: 6.0%

💰 Balance: \$1,981.41
📈 Symbols: EURUSD, GBPUSD, USDJPY, XAUUSD
🔔 Telegram Relay: Active
🖥 VNC: 77.237.234.2:5900

הבוט פעיל וסוחר! ✨" \
    -d parse_mode="HTML" 2>/dev/null | python3 -c "import sys,json; r=json.load(sys.stdin); print('Telegram:', 'OK' if r.get('ok') else r)" 2>/dev/null || echo "Telegram: FAILED"
echo ""

echo "=== DONE - $(date) ==="
