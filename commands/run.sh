#!/bin/bash
# Debug: check MT5 state + try to fix EA loading
echo "=== DEBUG MT5 $(date) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. Is MT5 running?
echo "=== PROCESS ==="
pgrep -fa terminal64

# 2. Check ALL log files (newest first)
echo ""
echo "=== ALL LOG FILES ==="
find "$MT5/Logs" -name "*.log" -printf "%T+ %p\n" 2>/dev/null | sort -r | head -5
find "$MT5/MQL5/Logs" -name "*.log" -printf "%T+ %p\n" 2>/dev/null | sort -r | head -5

# 3. Check the NEWEST MT5 main log
echo ""
echo "=== NEWEST MT5 LOG ==="
LATEST=$(find "$MT5/Logs" -name "*.log" -printf "%T+ %p\n" 2>/dev/null | sort -r | head -1 | awk '{print $2}')
if [ -n "$LATEST" ]; then
    echo "File: $LATEST ($(stat -c%s "$LATEST") bytes)"
    iconv -f UTF-16LE -t UTF-8 "$LATEST" 2>/dev/null | tail -30
fi

# 4. Check the NEWEST EA log
echo ""
echo "=== NEWEST EA LOG ==="
LATEST=$(find "$MT5/MQL5/Logs" -name "*.log" -printf "%T+ %p\n" 2>/dev/null | sort -r | head -1 | awk '{print $2}')
if [ -n "$LATEST" ]; then
    echo "File: $LATEST ($(stat -c%s "$LATEST") bytes)"
    iconv -f UTF-16LE -t UTF-8 "$LATEST" 2>/dev/null | tail -30
fi

# 5. Check if chart profile was loaded
echo ""
echo "=== CHART DIR CONTENTS ==="
ls -la "$MT5/MQL5/Profiles/Charts/Default/" 2>/dev/null

# 6. What is our chart01.chr content?
echo ""
echo "=== OUR CHART FILE ==="
cat "$MT5/MQL5/Profiles/Charts/Default/chart01.chr" 2>/dev/null

# 7. Did MT5 create its own chart files?
echo ""
echo "=== ANY NEW CHR FILES? ==="
find "$MT5" -name "*.chr" -newer "$MT5/MQL5/Experts/PropFirmBot/PropFirmBot.ex5" 2>/dev/null

# 8. Check stderr/stdout from wine
echo ""
echo "=== WINE ERRORS ==="
dmesg 2>/dev/null | grep -i "wine\|segfault" | tail -5
# Check if there's a crash dump
find /tmp -name "*.dmp" -newer /tmp 2>/dev/null | head -3

echo ""
echo "=== DONE ==="
