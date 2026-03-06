#!/bin/bash
# Get screenshot + check AutoTrading state properly (handle UTF-16 log)
echo "=== CHECK + SCREENSHOT $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. Copy screenshot to repo
echo "[1] Screenshot..."
if [ -f /tmp/mt5_screenshot.png ]; then
    cp /tmp/mt5_screenshot.png /root/MT5-PropFirm-Bot/commands/mt5_screenshot.png
    ls -la /root/MT5-PropFirm-Bot/commands/mt5_screenshot.png
    echo "Screenshot copied to repo"
else
    echo "No screenshot found, taking new one..."
    scrot /root/MT5-PropFirm-Bot/commands/mt5_screenshot.png 2>/dev/null || echo "scrot failed"
fi
echo ""

# 2. Check AutoTrading state properly - convert log from UTF-16 to UTF-8
echo "[2] AutoTrading state history:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
# The log might be UTF-16LE with null bytes
iconv -f UTF-16LE -t UTF-8 "$EALOG" 2>/dev/null | grep -i "automated trading" || \
  cat "$EALOG" 2>/dev/null | tr -d '\0' | grep -i "automated trading" || \
  echo "Could not find autotrading messages"
echo ""

# 3. Last state
echo "[3] Current EA state:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -10
echo ""

# 4. mt5_status.json
echo "[4] Status:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null | head -10

echo ""
echo "=== DONE $(date -u) ==="
