#!/bin/bash
# Trigger: v88 - Find missing EA file and check MT5 setup
cd /root/MT5-PropFirm-Bot

echo "=== EA SEARCH v88 - $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="

# Step 1: Find ANY .ex5 or .mq5 files on the system
echo "--- Step 1: Search for .ex5 files ---"
find /root -name "*.ex5" -type f 2>/dev/null
echo ""

echo "--- Step 2: Search for .mq5 source files ---"
find /root -name "*.mq5" -type f 2>/dev/null
echo ""

echo "--- Step 3: Search for PropFirmBot anywhere ---"
find /root -name "*PropFirmBot*" -type f 2>/dev/null
echo ""

# Step 4: Show MT5 directory structure
echo "--- Step 4: MT5 MQL5 directory ---"
MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
ls -la "$MT5_DIR/MQL5/Experts/" 2>/dev/null || echo "Experts dir not found"
echo ""
ls -la "$MT5_DIR/MQL5/Experts/PropFirmBot/" 2>/dev/null || echo "PropFirmBot subdir not found"
echo ""

echo "--- Step 5: Full MQL5 tree ---"
find "$MT5_DIR/MQL5/" -maxdepth 3 -type f -name "*.ex5" -o -name "*.mq5" 2>/dev/null
echo ""

# Step 6: Check if Python bot service exists
echo "--- Step 6: Python bot service ---"
systemctl status futures-bot --no-pager 2>&1 | head -5 || echo "futures-bot service not found"
echo ""

# Step 7: Check repo state
echo "--- Step 7: Repo state ---"
echo "Branch: $(git branch --show-current)"
echo "Last commit: $(git log --oneline -1)"
echo ""

# Step 8: MT5 terminal log (recent)
echo "--- Step 8: MT5 terminal log (last 20 lines) ---"
LATEST_LOG=$(ls -t "$MT5_DIR/logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "File: $LATEST_LOG"
    tail -20 "$LATEST_LOG"
else
    echo "No MT5 terminal logs found"
fi
echo ""

# Step 9: EA log (recent)
echo "--- Step 9: EA logs ---"
LATEST_EA_LOG=$(ls -t "$MT5_DIR/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_EA_LOG" ]; then
    echo "File: $LATEST_EA_LOG"
    tail -20 "$LATEST_EA_LOG"
else
    echo "No EA logs found"
fi
echo ""

# Step 10: Check if .ex5 in repo
echo "--- Step 10: .ex5 files in repo ---"
find /root/MT5-PropFirm-Bot -name "*.ex5" -type f 2>/dev/null || echo "No .ex5 in repo"
echo ""

echo "=== SEARCH COMPLETE ==="
