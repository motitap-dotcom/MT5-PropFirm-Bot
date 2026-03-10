#!/bin/bash
# =============================================================
# Pull latest code & Recompile PropFirmBot EA on VPS
# =============================================================

echo "============================================"
echo "  Pull & Compile PropFirmBot EA"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
REPO_DIR="/root/MT5-PropFirm-Bot"

# Step 1: Pull latest code from repo
echo "=== [1] Pull latest code ==="
cd "$REPO_DIR"
git fetch origin master 2>&1
git checkout master 2>&1
git pull origin master 2>&1
echo ""

# Step 2: Copy EA files to MT5 directory
echo "=== [2] Copy EA files ==="
cp -v "$REPO_DIR"/EA/*.mq5 "$EA_DIR/" 2>&1
cp -v "$REPO_DIR"/EA/*.mqh "$EA_DIR/" 2>&1
echo ""

# Step 3: Copy config files
echo "=== [3] Copy config files ==="
CONFIG_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"
mkdir -p "$CONFIG_DIR"
cp -v "$REPO_DIR"/configs/*.json "$CONFIG_DIR/" 2>&1
echo ""

# Step 4: Compile EA using MetaEditor
echo "=== [4] Compile PropFirmBot.mq5 ==="
cd "$EA_DIR"
echo "Files in EA directory:"
ls -la *.mq5 *.mqh 2>/dev/null
echo ""

WINEPREFIX=/root/.wine wine "${MT5_BASE}/metaeditor64.exe" /compile:PropFirmBot.mq5 /log 2>/dev/null || true
sleep 5

echo ""
echo "=== [5] Compilation result ==="
ls -la *.ex5 2>/dev/null && echo "OK - .ex5 file found" || echo "WARNING: No .ex5 file found"

# Check compilation log if exists
if [ -f "PropFirmBot.log" ]; then
    echo ""
    echo "=== Compilation log ==="
    cat PropFirmBot.log 2>/dev/null
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
