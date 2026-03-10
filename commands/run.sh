#!/bin/bash
# v4.0 Deploy - fast version
echo "=== Deploy v4.0 $(date -u) ==="

REPO="/root/MT5-PropFirm-Bot"
BRANCH="claude/redesign-bot-strategy-woBVq"
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA="${MT5}/MQL5/Experts/PropFirmBot"
CFG="${MT5}/MQL5/Files/PropFirmBot"

# Pull
cd "$REPO" && git fetch origin "$BRANCH" && git checkout "$BRANCH" && git reset --hard "origin/$BRANCH"
echo "Commit: $(git log --oneline -1)"

# Copy
mkdir -p "$EA" "$CFG"
cp EA/*.mq5 EA/*.mqh "$EA/"
cp configs/*.json "$CFG/"
echo "Files copied OK"

# Compile
cd "$EA"
WINEPREFIX=/root/.wine wine "${MT5}/metaeditor64.exe" /compile:PropFirmBot.mq5 /log 2>/dev/null
sleep 3
ls -la *.ex5 2>/dev/null && echo "COMPILE OK" || echo "COMPILE WARN"

# Restart MT5
pkill -f terminal64.exe 2>/dev/null
sleep 2
export DISPLAY=:99 WINEPREFIX=/root/.wine
pgrep Xvfb >/dev/null || (Xvfb :99 -screen 0 1280x1024x24 & sleep 1)
pgrep x11vnc >/dev/null || x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
wine "${MT5}/terminal64.exe" &
sleep 5

# Verify
pgrep -a terminal64 && echo "MT5 RUNNING OK" || echo "MT5 NOT RUNNING"
echo "=== DONE $(date -u) ==="
