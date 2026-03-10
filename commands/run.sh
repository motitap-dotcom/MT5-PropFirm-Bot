#!/bin/bash
# =============================================================
# Check if EA needs recompilation - 2026-03-10
# =============================================================

echo "============================================"
echo "  Check EA compilation status"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

EA_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot"

# 1. Compare dates
echo "=== [1] File dates ==="
echo "Compiled .ex5:"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
echo ""
echo "Source .mq5:"
ls -la "$EA_DIR/PropFirmBot.mq5" 2>/dev/null
echo ""
echo "Latest .mqh changes:"
ls -lt "$EA_DIR"/*.mqh 2>/dev/null | head -5
echo ""

# 2. Check what git commit is on VPS
echo "=== [2] VPS Git Info ==="
cd /root/MT5-PropFirm-Bot
echo "Branch: $(git branch --show-current)"
echo "Last commits:"
git log --oneline -5
echo ""
echo "Last deploy/pull:"
git reflog | head -5
echo ""

# 3. Check if there's a compile script or MetaEditor
echo "=== [3] MetaEditor available? ==="
find /root/.wine -name "metaeditor64.exe" 2>/dev/null || echo "MetaEditor not found"
echo ""

# 4. Check recent EA log for errors/version info
echo "=== [4] EA startup log (first 20 lines today) ==="
EA_LOG=$(ls -t /root/.wine/drive_c/Program\ Files/MetaTrader\ 5/MQL5/Logs/20260310.log 2>/dev/null)
if [ -n "$EA_LOG" ]; then
    head -20 "$EA_LOG"
else
    echo "No EA log for today"
fi
echo ""

# 5. Check main repo branch EA files vs VPS
echo "=== [5] Compare source file sizes (repo vs EA dir) ==="
echo "--- Repo files ---"
ls -la /root/MT5-PropFirm-Bot/EA/*.mq5 /root/MT5-PropFirm-Bot/EA/*.mqh 2>/dev/null | awk '{print $5, $9}'
echo ""
echo "--- EA dir files ---"
ls -la "$EA_DIR"/*.mq5 "$EA_DIR"/*.mqh 2>/dev/null | awk '{print $5, $9}'
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
