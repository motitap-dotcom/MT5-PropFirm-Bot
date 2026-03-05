#!/bin/bash
# FULL FIX: kill all MT5, disable watchdog, start clean, check correct logs
echo "=== FULL FIX $(date) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. First check the MT5 main log we missed (lowercase 'logs/')
echo "=== MT5 MAIN LOG (lowercase logs/) ==="
MAINLOG="$MT5/logs/20260305.log"
if [ -f "$MAINLOG" ]; then
    SIZE=$(stat -c%s "$MAINLOG")
    echo "File: $MAINLOG ($SIZE bytes)"
    iconv -f UTF-16LE -t UTF-8 "$MAINLOG" 2>/dev/null | tail -30
fi

# 2. Also check compile log
echo ""
echo "=== COMPILE LOG ==="
COMPLOG="$MT5/MQL5/Experts/PropFirmBot/PropFirmBot.log"
if [ -f "$COMPLOG" ]; then
    cat "$COMPLOG" 2>/dev/null | tail -20
fi

# 3. Disable watchdog temporarily
echo ""
echo "=== DISABLING WATCHDOG ==="
crontab -l 2>/dev/null > /tmp/cron_backup.txt
crontab -l 2>/dev/null | grep -v "watchdog" | crontab -
echo "Watchdog cron removed. Backup at /tmp/cron_backup.txt"
echo "Current crontab:"
crontab -l 2>/dev/null

# 4. Kill ALL MT5 and wine processes
echo ""
echo "=== KILLING ALL MT5 ==="
pkill -9 -f terminal64 2>/dev/null
pkill -9 -f start.exe 2>/dev/null
sleep 3

# Verify nothing is running
echo "Remaining MT5 processes:"
pgrep -fa terminal64 || echo "None"

# 5. Start MT5 fresh with /portable
echo ""
echo "=== STARTING FRESH MT5 ==="
cd "$MT5"
nohup wine64 terminal64.exe /portable > /tmp/mt5_output.txt 2>&1 &
MT5_PID=$!
echo "Started MT5 PID: $MT5_PID"

# Wait for startup
echo "Waiting 120 seconds for full initialization..."
sleep 120

# 6. Check results
echo ""
echo "=== NEW EA LOG ==="
EALOG="$MT5/MQL5/Logs/20260305.log"
if [ -f "$EALOG" ]; then
    NEWSIZE=$(stat -c%s "$EALOG")
    echo "Size: $NEWSIZE bytes (was 102898)"
    if [ "$NEWSIZE" -gt 102898 ]; then
        echo "NEW ENTRIES!"
    fi
    iconv -f UTF-16LE -t UTF-8 "$EALOG" 2>/dev/null | tail -30
fi

echo ""
echo "=== NEW MT5 MAIN LOG ==="
if [ -f "$MAINLOG" ]; then
    NEWSIZE=$(stat -c%s "$MAINLOG")
    echo "Size: $NEWSIZE bytes"
    iconv -f UTF-16LE -t UTF-8 "$MAINLOG" 2>/dev/null | tail -30
fi

echo ""
echo "=== WINE OUTPUT ==="
cat /tmp/mt5_output.txt 2>/dev/null | grep -v "fixme:\|err:toolbar" | head -20

echo ""
echo "=== PROCESS CHECK ==="
pgrep -fa terminal64 || echo "MT5 NOT running!"

# 7. Re-enable watchdog
echo ""
echo "=== RE-ENABLING WATCHDOG ==="
crontab /tmp/cron_backup.txt
echo "Watchdog restored"

echo ""
echo "=== DONE $(date) ==="
