#!/bin/bash
# Check if deploy happened and verify EA is running with fixes
echo "=== POST-DEPLOY CHECK $(date '+%Y-%m-%d %H:%M:%S %Z') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"

# 1. Check EA file timestamps - were they updated?
echo "--- EA file timestamps ---"
ls -la "$EA_DIR/PropFirmBot.mq5" "$EA_DIR/RiskManager.mqh" "$EA_DIR/PropFirmBot.ex5" 2>/dev/null

# 2. If EA files are old, deploy manually
echo ""
echo "--- Checking if manual deploy needed ---"
EA_MQ5_DATE=$(stat -c %Y "$EA_DIR/PropFirmBot.mq5" 2>/dev/null)
CURRENT_TIME=$(date +%s)
AGE=$(( (CURRENT_TIME - EA_MQ5_DATE) / 60 ))
echo "PropFirmBot.mq5 age: ${AGE} minutes"

if [ "$AGE" -gt 10 ]; then
    echo "EA files are old - deploy didn't run. Checking repo..."
    cd /root/MT5-PropFirm-Bot || exit 1

    # Pull latest changes
    git fetch origin claude/fix-bot-trading-config-N1uDv 2>&1
    git checkout claude/fix-bot-trading-config-N1uDv 2>&1 || git checkout -b claude/fix-bot-trading-config-N1uDv origin/claude/fix-bot-trading-config-N1uDv 2>&1
    git pull origin claude/fix-bot-trading-config-N1uDv 2>&1

    # Copy EA files
    echo "Copying EA files..."
    cp -v EA/*.mq5 EA/*.mqh "$EA_DIR/" 2>&1

    # Copy config files
    cp -v configs/*.json "${MT5_BASE}/MQL5/Files/PropFirmBot/" 2>&1

    # Recompile
    echo "Recompiling EA..."
    cd "$EA_DIR"
    WINEPREFIX=/root/.wine wine "/root/.wine/drive_c/Program Files/MetaTrader 5/metaeditor64.exe" /compile:PropFirmBot.mq5 /log 2>/dev/null || true
    sleep 5
    ls -la *.ex5 2>/dev/null
    echo "Deploy done manually"
fi

# 3. Check latest EA log for new entries
echo ""
echo "--- Latest EA log (last 30 lines, converted from UTF-16) ---"
EA_LATEST=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$EA_LATEST" ]; then
    echo "File: $EA_LATEST"
    TMPLOG="/tmp/ea_check.txt"
    iconv -f UTF-16LE -t UTF-8 "$EA_LATEST" 2>/dev/null > "$TMPLOG" || \
      sed 's/\x00//g' "$EA_LATEST" > "$TMPLOG"
    tail -30 "$TMPLOG"
    echo ""
    echo "--- NEWBAR count ---"
    grep -c "NEWBAR" "$TMPLOG"
    echo "--- M15 bars (non-hourly) ---"
    grep "NEWBAR" "$TMPLOG" | grep -v ":00 |" | head -10
    echo "--- Session check logs ---"
    grep "Session check" "$TMPLOG" | tail -5
    echo "--- SCAN entries ---"
    grep "\[SCAN\]" "$TMPLOG" | tail -10
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
