#!/bin/bash
# ============================================
# PropFirmBot - Deploy Fix & Start Dashboard
# Run on VPS: bash /root/MT5-PropFirm-Bot/scripts/deploy_fix.sh
# ============================================

set -e

REPO="/root/MT5-PropFirm-Bot"
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
CONFIG_DIR="$MT5/MQL5/Files/PropFirmBot"

echo "============================================"
echo "  PropFirmBot - Deploy Fix"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"

# Step 1: Pull latest code
echo ""
echo "[1/6] Pulling latest code..."
cd "$REPO"
git fetch origin claude/build-cfd-trading-bot-fl0ld
git checkout claude/build-cfd-trading-bot-fl0ld
git pull origin claude/build-cfd-trading-bot-fl0ld

# Step 2: Copy EA files
echo ""
echo "[2/6] Copying EA files..."
mkdir -p "$EA_DIR"
cp -v "$REPO/EA/"*.mq5 "$EA_DIR/"
cp -v "$REPO/EA/"*.mqh "$EA_DIR/"

# Step 3: Copy config files
echo ""
echo "[3/6] Copying config files..."
mkdir -p "$CONFIG_DIR"
cp -v "$REPO/configs/"*.json "$CONFIG_DIR/"

# Step 4: Add WebRequest URL for Telegram
echo ""
echo "[4/6] Checking WebRequest URL..."
echo "NOTE: You must manually add https://api.telegram.org in MT5:"
echo "  Tools > Options > Expert Advisors > Allow WebRequest for listed URL"
echo "  Then add: https://api.telegram.org"

# Step 5: Compile EA
echo ""
echo "[5/6] Compiling EA..."
METAEDITOR="$MT5/metaeditor64.exe"
if [ -f "$METAEDITOR" ]; then
    cd "$MT5"
    timeout 60 wine64 "$METAEDITOR" /compile:"MQL5/Experts/PropFirmBot/PropFirmBot.mq5" /log 2>/dev/null || true
    sleep 3

    if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
        SIZE=$(stat -c%s "$EA_DIR/PropFirmBot.ex5")
        echo "SUCCESS! PropFirmBot.ex5 = $SIZE bytes"
    else
        echo "WARNING: .ex5 not found after compile. May need manual compile in MT5."
    fi
else
    echo "WARNING: MetaEditor not found. Compile manually in MT5."
fi

# Step 6: Start web dashboard
echo ""
echo "[6/6] Starting web dashboard..."
# Kill any existing dashboard
pkill -f web_dashboard.py 2>/dev/null || true
sleep 1

# Start dashboard in background
nohup python3 "$REPO/scripts/web_dashboard.py" > /var/log/propfirmbot_dashboard.log 2>&1 &
DASH_PID=$!
sleep 2

if kill -0 $DASH_PID 2>/dev/null; then
    echo "Dashboard started! PID: $DASH_PID"
    echo "Access: http://77.237.234.2:8080"
else
    echo "WARNING: Dashboard failed to start. Check /var/log/propfirmbot_dashboard.log"
fi

# Open firewall for dashboard
ufw allow 8080/tcp 2>/dev/null || iptables -I INPUT -p tcp --dport 8080 -j ACCEPT 2>/dev/null || true

echo ""
echo "============================================"
echo "  DEPLOYMENT COMPLETE!"
echo "============================================"
echo ""
echo "IMPORTANT - You need to restart the EA in MT5:"
echo "  1. Open VNC (RealVNC -> 77.237.234.2:5900)"
echo "  2. In MT5: Right-click EA on chart > Remove"
echo "  3. Drag PropFirmBot from Navigator > Expert Advisors back to chart"
echo "  4. Check 'Allow AutoTrading' and click OK"
echo "  5. Make sure green AutoTrading button is ON"
echo ""
echo "ALSO - Add WebRequest URL:"
echo "  Tools > Options > Expert Advisors"
echo "  Check 'Allow WebRequest for listed URL'"
echo "  Add: https://api.telegram.org"
echo ""
echo "Web Dashboard: http://77.237.234.2:8080"
echo "============================================"
