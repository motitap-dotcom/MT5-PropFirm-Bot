#!/bin/bash
# Find MetaEditor and compile the new EA
echo "=== COMPILE EA $(date -u) ==="
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. Find MetaEditor
echo "[1] Finding MetaEditor..."
find /root/.wine -name "metaeditor*" -type f 2>/dev/null
find /root/.wine -iname "*editor*" -type f 2>/dev/null | grep -i meta
echo ""

# 2. Check if MT5 terminal can compile (it has built-in compiler)
echo "[2] MT5 directory contents:"
ls "$MT5/"*.exe 2>/dev/null
echo ""

# 3. Try to trigger MT5 recompilation
echo "[3] Touching .mq5 to force recompile..."
touch "$EA_DIR/PropFirmBot.mq5"
echo "Before:"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>&1
echo ".mq5:"
ls -la "$EA_DIR/PropFirmBot.mq5" 2>&1
echo ""

# 4. Stop MT5, delete old .ex5, restart to force recompile
echo "[4] Removing old .ex5 to force recompile..."
pkill -f terminal64 2>/dev/null
sleep 3

# Backup old .ex5
cp "$EA_DIR/PropFirmBot.ex5" "$EA_DIR/PropFirmBot.ex5.bak_$(date +%Y%m%d_%H%M)" 2>/dev/null
rm -f "$EA_DIR/PropFirmBot.ex5"
echo "Removed old .ex5"
echo ""

# 5. Start MT5 - it should recompile the EA
echo "[5] Starting MT5 (should auto-compile)..."
pgrep Xvfb || (Xvfb :99 -screen 0 1280x1024x24 & sleep 2)
nohup wine "$MT5/terminal64.exe" /portable /login:11797849 /server:FundedNext-Server /autotrading > /dev/null 2>&1 &
echo "Waiting 30 seconds for MT5 to compile and load EA..."
sleep 30

# 6. Check if .ex5 was created
echo "[6] Checking compilation:"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>&1
echo ""

# 7. Check EA log for AUTOFIX messages
echo "[7] EA log:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep -i "AUTOFIX\|AutoTrading\|DLL\|auto.fix" | tail -10
echo ""
echo "Last 10 lines:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -10

echo ""
echo "=== DONE $(date -u) ==="
