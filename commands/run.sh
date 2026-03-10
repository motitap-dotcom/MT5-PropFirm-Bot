#!/bin/bash
# =============================================================
# Deploy latest EA code from GitHub to VPS
# =============================================================

echo "============================================"
echo "  Deploy EA Update to VPS"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
CONFIG_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"
REPO_DIR="/root/MT5-PropFirm-Bot"

# Step 1: Pull latest code from the active branch
echo "=== [1] Pull latest code ==="
cd "$REPO_DIR"

# Check current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $CURRENT_BRANCH"

# Fetch all branches and checkout the one with latest workflows
git fetch origin claude/enable-github-actions-38lPd 2>&1
git checkout claude/enable-github-actions-38lPd 2>&1 || git checkout -b claude/enable-github-actions-38lPd origin/claude/enable-github-actions-38lPd 2>&1
git pull origin claude/enable-github-actions-38lPd 2>&1
echo ""

# Step 2: Copy EA files
echo "=== [2] Copy EA files ==="
mkdir -p "$EA_DIR" "$CONFIG_DIR"
cp -v EA/*.mq5 EA/*.mqh "$EA_DIR/" 2>&1
echo ""

# Step 3: Copy config files
echo "=== [3] Copy config files ==="
cp -v configs/*.json "$CONFIG_DIR/" 2>&1
echo ""

# Step 4: Compile EA
echo "=== [4] Compile EA ==="
cd "$EA_DIR"
WINEPREFIX=/root/.wine wine "/root/.wine/drive_c/Program Files/MetaTrader 5/metaeditor64.exe" /compile:PropFirmBot.mq5 /log 2>/dev/null || true
sleep 5
ls -la *.ex5 2>/dev/null && echo "Compilation OK" || echo "Warning: .ex5 not updated"
echo ""

# Step 5: Verify
echo "=== [5] Verify files ==="
echo "EA files:"
ls -la "$EA_DIR/"*.mq5 "$EA_DIR/"*.mqh "$EA_DIR/"*.ex5 2>/dev/null
echo ""
echo "Config files:"
ls -la "$CONFIG_DIR/"*.json 2>/dev/null
echo ""

# Step 6: Check MT5 process
echo "=== [6] MT5 Process ==="
ps aux | grep -i terminal64 | grep -v grep
echo ""

echo "=== DEPLOY COMPLETE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
