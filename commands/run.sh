#!/bin/bash
# Reset circuit breaker by restarting MT5 EA - 2026-03-16d
echo "=== RESET CIRCUIT BREAKER $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
REPO_DIR="/root/MT5-PropFirm-Bot"

# 1. Pull latest code from repo (get the Guardian.mqh fix)
echo "--- Pulling latest code ---"
cd "$REPO_DIR" && git fetch origin && git pull origin main 2>&1 || echo "Pull from main failed, trying current branch"
git pull 2>&1 || true

# 2. Copy updated EA files to MT5 directory
echo ""
echo "--- Copying updated EA files ---"
for f in EA/*.mq5 EA/*.mqh; do
    if [ -f "$f" ]; then
        cp "$f" "$EA_DIR/" && echo "Copied: $f"
    fi
done

# 3. Recompile EA with MetaEditor
echo ""
echo "--- Recompiling EA ---"
cd "$EA_DIR"
WINEPREFIX=/root/.wine wine "${MT5_BASE}/metaeditor64.exe" /compile:PropFirmBot.mq5 /log 2>/dev/null || true
sleep 5
ls -la *.ex5 2>/dev/null
echo ""

# 4. Check if MT5 detected the new .ex5 (it auto-reloads)
echo "--- Waiting for MT5 to detect new EA ---"
sleep 10

# 5. Verify status after reload
echo ""
echo "--- Status after reset ---"
EA_FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"
if [ -f "$EA_FILES_DIR/status.json" ]; then
    cat "$EA_FILES_DIR/status.json"
fi

echo ""
echo "--- Latest EA Log (last 20 lines) ---"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"
TODAY_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$TODAY_LOG" ]; then
    iconv -f UTF-16LE -t UTF-8 "$TODAY_LOG" 2>/dev/null | tail -20
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
