#!/bin/bash
# Fix: AutoTrading in terminal.ini + Enable WebRequest for Telegram
echo "=== FIX terminal.ini + WebRequest $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. Show current terminal.ini
echo "[1] Current terminal.ini:"
cat "$MT5/terminal.ini" 2>/dev/null
echo ""
echo "---END OF FILE---"
echo ""

# 2. Fix terminal.ini - add AutoTrading properly
echo "[2] Fixing terminal.ini..."
INI="$MT5/terminal.ini"

# Check if [Common] section exists
if grep -q '\[Common\]' "$INI" 2>/dev/null; then
    # Add AutoTrading=1 after [Common] if not there
    if ! grep -q 'AutoTrading=' "$INI"; then
        sed -i '/\[Common\]/a AutoTrading=1' "$INI"
        echo "Added AutoTrading=1 under [Common]"
    fi
else
    # Create [Common] section with AutoTrading
    echo -e "\n[Common]\nAutoTrading=1" >> "$INI"
    echo "Created [Common] section with AutoTrading=1"
fi

# 3. Fix WebRequest - add Telegram URL to allowed URLs
echo ""
echo "[3] Fixing WebRequest for Telegram..."

# Check/create expert settings in common.ini
CINI="$MT5/config/common.ini"
echo "Current common.ini:"
cat "$CINI" 2>/dev/null || echo "(file not found)"
echo "---END---"
echo ""

# WebRequest URLs need to be in the EA settings / common.ini
# In MT5, WebRequest URLs go under [Experts] section
if [ -f "$CINI" ]; then
    if ! grep -q 'AllowedURLs' "$CINI" 2>/dev/null; then
        if grep -q '\[Experts\]' "$CINI" 2>/dev/null; then
            sed -i '/\[Experts\]/a AllowedURLs=https://api.telegram.org' "$CINI"
        else
            echo -e "\n[Experts]\nAllowedURLs=https://api.telegram.org\nAutoTrading=1" >> "$CINI"
        fi
        echo "Added AllowedURLs for Telegram"
    fi
else
    mkdir -p "$MT5/config"
    cat > "$CINI" << 'EOINI'
[Common]
AutoTrading=1

[Experts]
AllowedURLs=https://api.telegram.org
AutoTrading=1
AllowWebRequest=1
EOINI
    echo "Created common.ini with WebRequest and AutoTrading"
fi

# 4. Also check/fix the expert.ini where MT5 stores WebRequest URLs
EXPERT_INI="$MT5/config/expert.ini"
echo ""
echo "[4] expert.ini:"
cat "$EXPERT_INI" 2>/dev/null || echo "(not found)"
echo ""

# MT5 stores allowed URLs in terminal.ini under [WebRequest]
echo "[5] Adding WebRequest section to terminal.ini..."
if ! grep -q '\[WebRequest\]' "$INI" 2>/dev/null; then
    echo -e "\n[WebRequest]\nhttps://api.telegram.org=1" >> "$INI"
    echo "Added [WebRequest] section"
fi

# Also check if there's an [Experts] section in terminal.ini
if ! grep -q '\[Experts\]' "$INI" 2>/dev/null; then
    echo -e "\n[Experts]\nAllowDLL=0\nAllowWebRequest=1\nWebRequestURL=https://api.telegram.org" >> "$INI"
    echo "Added [Experts] section"
elif ! grep -q 'AllowWebRequest' "$INI" 2>/dev/null; then
    sed -i '/\[Experts\]/a AllowWebRequest=1\nWebRequestURL=https://api.telegram.org' "$INI"
    echo "Added WebRequest to [Experts]"
fi

echo ""
echo "[6] Final terminal.ini:"
cat "$INI"
echo ""

# 7. Restart MT5 to apply changes
echo "[7] Restarting MT5..."
pkill -f terminal64 2>/dev/null
sleep 5

export DISPLAY=:99
export WINEPREFIX=/root/.wine
pgrep Xvfb || (Xvfb :99 -screen 0 1280x1024x24 & sleep 2)

nohup wine "$MT5/terminal64.exe" /portable /login:11797849 /server:FundedNext-Server /autotrading > /dev/null 2>&1 &
sleep 10

if pgrep -f terminal64 > /dev/null; then
    echo "MT5 RUNNING OK"
else
    echo "MT5 FAILED - retrying"
    nohup wine "$MT5/terminal64.exe" /portable /login:11797849 /server:FundedNext-Server /autotrading > /dev/null 2>&1 &
    sleep 10
    pgrep -f terminal64 && echo "MT5 RUNNING (2nd)" || echo "FAILED"
fi

echo "=== DONE $(date -u) ==="
