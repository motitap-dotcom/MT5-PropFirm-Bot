#!/bin/bash
# =============================================================
# Check running bot version and EA details on VPS
# =============================================================

echo "============================================"
echo "  Bot Version Check"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# 1. Check EA source file header/version
echo "=== [1] EA Source Version (PropFirmBot.mq5 header) ==="
EA_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot"
if [ -f "$EA_DIR/PropFirmBot.mq5" ]; then
    head -50 "$EA_DIR/PropFirmBot.mq5" | grep -iE "version|property|copyright|description|define.*VERSION"
    echo ""
    echo "File date:"
    ls -la "$EA_DIR/PropFirmBot.mq5"
else
    echo "PropFirmBot.mq5 NOT FOUND at $EA_DIR"
fi
echo ""

# 2. Check compiled .ex5 file date
echo "=== [2] Compiled EA (.ex5) file date ==="
if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
    ls -la "$EA_DIR/PropFirmBot.ex5"
else
    echo "PropFirmBot.ex5 NOT FOUND"
fi
echo ""

# 3. List all EA module files and dates
echo "=== [3] All EA module files ==="
ls -la "$EA_DIR/"*.mq5 "$EA_DIR/"*.mqh 2>/dev/null || echo "No files found"
echo ""

# 4. Check repo version on VPS
echo "=== [4] Git repo state on VPS ==="
cd /root/MT5-PropFirm-Bot 2>/dev/null && {
    echo "Branch: $(git rev-parse --abbrev-ref HEAD)"
    echo "Last commit: $(git log -1 --format='%h %s (%ci)')"
    echo "Remote URL: $(git remote get-url origin)"
} || echo "Repo not found at /root/MT5-PropFirm-Bot"
echo ""

# 5. Check if MT5 is running
echo "=== [5] MT5 Process Status ==="
pgrep -a terminal64 || pgrep -a metatrader || echo "MT5 process not found"
echo ""

# 6. Check config files
echo "=== [6] Config files dates ==="
CONFIG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot"
ls -la "$CONFIG_DIR/"*.json 2>/dev/null || echo "No config files found at $CONFIG_DIR"
echo ""

# 7. MT5 journal/log (last 20 lines)
echo "=== [7] MT5 Experts Log (last 20 lines) ==="
LOGS_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs"
LATEST_LOG=$(ls -t "$LOGS_DIR/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "Log file: $LATEST_LOG"
    tail -20 "$LATEST_LOG"
else
    echo "No log files found"
fi
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
