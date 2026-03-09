#!/bin/bash
# =============================================================
# URGENT FIX: Restart MT5 and restore EA
# =============================================================

echo "============================================"
echo "  URGENT FIX - Restore MT5 & EA"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. Kill any lingering processes
echo "=== [1] Cleanup ==="
pkill -f terminal64.exe 2>/dev/null
pkill -f MetaEditor 2>/dev/null
screen -wipe 2>/dev/null
sleep 3
echo "Cleaned up"
echo ""

# 2. Check display
echo "=== [2] Display check ==="
if pgrep -f Xvfb > /dev/null; then
    echo "Xvfb running OK"
else
    echo "Starting Xvfb..."
    Xvfb :99 -screen 0 1280x1024x24 -ac +extension GLX +render -noreset &
    sleep 2
fi
echo ""

# 3. Check .ex5 and try to get it back
echo "=== [3] EA status ==="
if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
    echo ".ex5 EXISTS:"
    ls -la "$EA_DIR/PropFirmBot.ex5"
else
    echo ".ex5 MISSING - trying to compile via MT5..."
    echo "Source files present:"
    ls -la "$EA_DIR/PropFirmBot.mq5" 2>/dev/null
fi
echo ""

# 4. Start MT5 - it will auto-compile .mq5 when loading EA
echo "=== [4] Start MT5 ==="
cd "$MT5_DIR"
screen -dmS mt5 bash -c "export DISPLAY=:99 && export WINEPREFIX=/root/.wine && cd '$MT5_DIR' && wine ./terminal64.exe /portable /login:11797849 /server:FundedNext-Server 2>&1"
echo "Waiting 30s for MT5 to start and auto-compile..."
sleep 30

if pgrep -f terminal64.exe > /dev/null; then
    echo "MT5 IS RUNNING!"
    ps aux | grep terminal64 | grep -v grep | head -1
else
    echo "MT5 still not running, trying alternative start..."
    # Try without screen
    nohup bash -c "export DISPLAY=:99 && export WINEPREFIX=/root/.wine && wine '$MT5_DIR/terminal64.exe' /portable /login:11797849 /server:FundedNext-Server" > /tmp/mt5_start.log 2>&1 &
    sleep 30
    if pgrep -f terminal64.exe > /dev/null; then
        echo "MT5 RUNNING (nohup method)"
    else
        echo "MT5 FAILED - start log:"
        cat /tmp/mt5_start.log 2>/dev/null | tail -20
    fi
fi
echo ""

# 5. Check if .ex5 was auto-compiled
echo "=== [5] .ex5 after MT5 start ==="
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo ".ex5 still missing"
echo ""

# 6. Final status
echo "=== [6] Final Status ==="
if [ -f /var/bots/mt5_status.json ]; then
    python3 -c "
import json
with open('/var/bots/mt5_status.json') as f:
    d = json.load(f)
print(f'Active: {d.get(\"active\", \"?\")}')
print(f'EA Connected: {d.get(\"ea_connected\", \"?\")}')
print(f'Balance: {d.get(\"balance\", \"?\")}')
print(f'Equity: {d[\"account\"][\"equity\"]}')
print(f'Open positions: {d.get(\"_open_positions_count\", \"?\")}')
print(f'Updated: {d.get(\"updated_at\", \"?\")}')
"
fi
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
