#!/bin/bash
# Check deploy status and compilation of news filter update
echo "=== DEPLOY VERIFICATION $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
EA_FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"

# 1. Check if NewsFilter.mqh has the new ShouldClosePositions function
echo "--- EA Files Check ---"
echo "NewsFilter.mqh:"
grep -c "ShouldClosePositions" "$EA_DIR/NewsFilter.mqh" 2>/dev/null && echo "  ShouldClosePositions: FOUND" || echo "  ShouldClosePositions: NOT FOUND"
grep -c "SetCloseBeforeNews" "$EA_DIR/NewsFilter.mqh" 2>/dev/null && echo "  SetCloseBeforeNews: FOUND" || echo "  SetCloseBeforeNews: NOT FOUND"

echo ""
echo "PropFirmBot.mq5:"
grep -c "InpNewsClosePos" "$EA_DIR/PropFirmBot.mq5" 2>/dev/null && echo "  InpNewsClosePos: FOUND" || echo "  InpNewsClosePos: NOT FOUND"
grep -c "NEWS PRE-CLOSE" "$EA_DIR/PropFirmBot.mq5" 2>/dev/null && echo "  NEWS PRE-CLOSE step: FOUND" || echo "  NEWS PRE-CLOSE step: NOT FOUND"

# 2. Check .ex5 file (compiled)
echo ""
echo "--- Compiled EA (.ex5) ---"
ls -la "$EA_DIR/"*.ex5 2>/dev/null || echo "No .ex5 files found"

# 3. Check if MT5 is running
echo ""
echo "--- MT5 Process ---"
if pgrep -f terminal64 > /dev/null 2>&1; then
    MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
    echo "MT5: RUNNING (PID=$MT5_PID)"
    echo "Uptime: $(ps -o etime= -p $MT5_PID 2>/dev/null)"
else
    echo "MT5: NOT RUNNING!"
fi

# 4. Recent EA logs - check for news filter activity
echo ""
echo "--- Recent EA Logs (last 20 lines) ---"
TODAY_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$TODAY_LOG" ]; then
    echo "Log: $TODAY_LOG"
    tail -20 "$TODAY_LOG" 2>&1
else
    echo "No EA log files found"
fi

# 5. Check deploy report
echo ""
echo "--- Deploy Report ---"
REPO_DIR="/root/MT5-PropFirm-Bot"
if [ -f "$REPO_DIR/deploy_report.txt" ]; then
    tail -30 "$REPO_DIR/deploy_report.txt"
else
    echo "No deploy_report.txt found"
fi

# 6. Status.json
echo ""
echo "--- status.json ---"
cat "$EA_FILES_DIR/status.json" 2>/dev/null || echo "status.json not found"

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
