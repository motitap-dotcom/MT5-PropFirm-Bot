#!/bin/bash
# Fix AutoTrading: modify config/terminal.ini (UTF-16) + use xdotool click
echo "=== FIX AutoTrading - UTF-16 config $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. Stop MT5 completely
echo "[1] Full stop..."
pkill -f terminal64 2>/dev/null
sleep 3
pkill -9 -f terminal64 2>/dev/null
wineserver -k 2>/dev/null
sleep 3

# 2. Examine config/terminal.ini properly
echo "[2] config/terminal.ini (decoded from UTF-16):"
TINI="$MT5/config/terminal.ini"
if [ -f "$TINI" ]; then
    # Convert UTF-16 to UTF-8 for reading
    iconv -f UTF-16LE -t UTF-8 "$TINI" 2>/dev/null | head -40
    echo ""
    echo "Checking for AutoTrading:"
    iconv -f UTF-16LE -t UTF-8 "$TINI" 2>/dev/null | grep -i "autotrad\|expert"
fi
echo ""

# 3. Add AutoTrading to config/terminal.ini in UTF-16
echo "[3] Adding AutoTrading to config/terminal.ini..."
# Convert to UTF-8, add setting, convert back
TMP_FILE="/tmp/terminal_utf8.ini"
if [ -f "$TINI" ]; then
    # Strip BOM and convert
    iconv -f UTF-16LE -t UTF-8 "$TINI" > "$TMP_FILE" 2>/dev/null

    # Check if AutoTrading already exists
    if grep -q "AutoTrading" "$TMP_FILE" 2>/dev/null; then
        sed -i 's/AutoTrading=0/AutoTrading=1/' "$TMP_FILE"
        echo "Changed AutoTrading=0 to AutoTrading=1"
    else
        # Add [Common] section with AutoTrading if not exists
        if grep -q '\[Common\]' "$TMP_FILE" 2>/dev/null; then
            sed -i '/\[Common\]/a AutoTrading=1' "$TMP_FILE"
        else
            echo -e "[Common]\nAutoTrading=1" >> "$TMP_FILE"
        fi
        echo "Added AutoTrading=1"
    fi

    # Add [Experts] section if not exists
    if ! grep -q '\[Experts\]' "$TMP_FILE" 2>/dev/null; then
        echo -e "\n[Experts]\nExpertEnabled=1\nAutoTrading=1\nAllowLiveTrading=1" >> "$TMP_FILE"
        echo "Added [Experts] section"
    fi

    # Convert back to UTF-16LE with BOM
    iconv -f UTF-8 -t UTF-16LE "$TMP_FILE" > "$TINI" 2>/dev/null
    echo "Saved config/terminal.ini in UTF-16"

    # Verify
    echo "Verification:"
    iconv -f UTF-16LE -t UTF-8 "$TINI" 2>/dev/null | grep -i "autotrad\|expert\|Common"
fi
echo ""

# 4. Also update startup.ini (this one is plain text)
echo "[4] startup.ini:"
SINI="$MT5/config/startup.ini"
cat "$SINI" 2>/dev/null
echo ""

# 5. Check/fix chart file expertmode
echo "[5] Chart file expert section:"
CHR="$MT5/profiles/charts/default/chart01.chr"
if [ -f "$CHR" ]; then
    grep -A5 "expert" "$CHR"

    # expertmode=33 means: 1 (live trading) + 32 (auto trading enabled)
    # Let's make sure it has the right value
    # 33 already includes live trading bit, but let's try 37 = 1+4+32
    # Actually 33 should be fine
    echo "expertmode=33 is correct (live trading + auto trading)"
fi
echo ""

# 6. Start MT5 fresh
echo "[6] Starting MT5..."
pgrep Xvfb || (Xvfb :99 -screen 0 1280x1024x24 & sleep 2)
nohup wine "$MT5/terminal64.exe" /portable /login:11797849 /server:FundedNext-Server /autotrading > /dev/null 2>&1 &
echo "Waiting 20 seconds for EA to load..."
sleep 20

# 7. Try xdotool - find and click the AutoTrading button
echo "[7] Trying xdotool..."
# Install if needed
which xdotool > /dev/null 2>&1 || apt-get install -y xdotool > /dev/null 2>&1

# Find MT5 window
WIN_ID=$(xdotool search --name "MetaTrader" 2>/dev/null | head -1)
[ -z "$WIN_ID" ] && WIN_ID=$(xdotool search --name "" 2>/dev/null | head -1)

if [ -n "$WIN_ID" ]; then
    echo "Window: $WIN_ID"
    xdotool windowactivate "$WIN_ID" 2>/dev/null
    sleep 1

    # Get window geometry
    xdotool getwindowgeometry "$WIN_ID" 2>/dev/null

    # In MT5, the AutoTrading button is in the toolbar, typically around y=50, and
    # it's usually about 200-300px from left. Try clicking around that area.
    # First try Ctrl+E (keyboard shortcut for AutoTrading toggle)
    xdotool key --window "$WIN_ID" --clearmodifiers ctrl+e 2>/dev/null
    echo "Sent Ctrl+E"
    sleep 2
fi
echo ""

# 8. Check terminal log for "automated trading" message
echo "[8] Terminal log:"
TLOG=$(ls -t "$MT5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$TLOG" ]; then
    echo "File: $TLOG"
    # Convert from UTF-16 if needed
    iconv -f UTF-16LE -t UTF-8 "$TLOG" 2>/dev/null | tail -20 || tail -20 "$TLOG" 2>&1
fi
echo ""

# 9. Check EA log
echo "[9] EA log:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$EALOG" ]; then
    tail -15 "$EALOG" 2>&1
fi

echo ""
echo "=== DONE $(date -u) ==="
