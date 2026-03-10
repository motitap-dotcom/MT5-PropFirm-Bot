#!/bin/bash
# Quick VPS connectivity test + deploy v4.0
echo "=== VPS Connectivity Test ==="
echo "Date: $(date -u)"
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime)"
echo ""

# Quick deploy
REPO="/root/MT5-PropFirm-Bot"
BRANCH="claude/redesign-bot-strategy-woBVq"
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5}/MQL5/Experts/PropFirmBot"
CFG_DIR="${MT5}/MQL5/Files/PropFirmBot"

echo "=== Pull latest ==="
cd "$REPO" 2>/dev/null && git fetch origin "$BRANCH" 2>&1 && git checkout "$BRANCH" 2>&1 && git pull origin "$BRANCH" 2>&1
echo "Commit: $(git log --oneline -1)"
echo ""

echo "=== Copy files ==="
mkdir -p "$EA_DIR" "$CFG_DIR"
cp -v EA/*.mq5 EA/*.mqh "$EA_DIR/" 2>&1
cp -v configs/*.json "$CFG_DIR/" 2>&1
echo ""

echo "=== Compile ==="
cd "$EA_DIR"
WINEPREFIX=/root/.wine wine "${MT5}/metaeditor64.exe" /compile:PropFirmBot.mq5 /log 2>/dev/null || true
sleep 5
ls -la *.ex5 2>/dev/null && echo "OK" || echo "WARN: no .ex5"
echo ""

echo "=== Restart MT5 ==="
pkill -f terminal64.exe 2>/dev/null; sleep 2
export DISPLAY=:99 WINEPREFIX=/root/.wine
pgrep Xvfb || (Xvfb :99 -screen 0 1280x1024x24 & sleep 2)
pgrep x11vnc || x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
wine "${MT5}/terminal64.exe" & sleep 8
echo ""

echo "=== Status ==="
pgrep -a terminal64 && echo "MT5 RUNNING" || echo "MT5 NOT RUNNING"
echo "=== DONE ==="
