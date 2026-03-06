#!/bin/bash
# Fix AutoTrading via proper startup config + wine registry
echo "=== FIX AUTOTRADING $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# Kill MT5
screen -X -S mt5 quit 2>/dev/null
pkill -9 -f terminal64.exe 2>/dev/null
pkill -9 -f "start.exe" 2>/dev/null
sleep 3

# Step 1: Fix startup.ini with AutoTrading=1 in [StartUp] section
echo "[1] Fixing startup.ini..."
cat > "$MT5/config/startup.ini" << 'STARTUP'
[StartUp]
Login=11797849
Server=FundedNext-Server
AutoTrading=1
AllowLiveTrading=1
AllowWebRequest=1
WebRequestUrl1=https://api.telegram.org

[Experts]
AllowLiveTrading=1
AllowDllImport=0
ExpertsEnabled=1
AutoTrading=1

[Expert]
Expert=PropFirmBot\PropFirmBot
ExpertParameters=
STARTUP
echo "  Done"
cat "$MT5/config/startup.ini"

# Step 2: Fix terminal.ini - read the real one and add AutoTrading
echo ""
echo "[2] Fixing terminal.ini..."
# Check if terminal.ini exists and its encoding
if [ -f "$MT5/config/terminal.ini" ]; then
    ENCODING=$(file "$MT5/config/terminal.ini")
    echo "  Encoding: $ENCODING"

    if echo "$ENCODING" | grep -q "UTF-16"; then
        # Convert to UTF-8, add AutoTrading, convert back
        iconv -f UTF-16LE -t UTF-8 "$MT5/config/terminal.ini" 2>/dev/null > /tmp/terminal_utf8.ini

        # Check if [Common] section exists
        if grep -q "\[Common\]" /tmp/terminal_utf8.ini; then
            # Add AutoTrading after [Common]
            sed -i '/\[Common\]/a AutoTrading=1' /tmp/terminal_utf8.ini 2>/dev/null
        else
            # Add [Common] section at the beginning
            sed -i '1i [Common]\nAutoTrading=1\n' /tmp/terminal_utf8.ini 2>/dev/null
        fi

        # Convert back to UTF-16
        iconv -f UTF-8 -t UTF-16LE /tmp/terminal_utf8.ini > "$MT5/config/terminal.ini"
        echo "  terminal.ini updated (UTF-16)"
    else
        # Plain text
        if ! grep -q "AutoTrading" "$MT5/config/terminal.ini"; then
            echo -e "\n[Common]\nAutoTrading=1" >> "$MT5/config/terminal.ini"
        fi
        sed -i 's/AutoTrading=0/AutoTrading=1/g' "$MT5/config/terminal.ini"
        echo "  terminal.ini updated (UTF-8)"
    fi
fi

# Step 3: Also check/fix common.ini
echo ""
echo "[3] Fixing common.ini..."
if ! grep -q "\[Common\]" "$MT5/config/common.ini" 2>/dev/null; then
    echo -e "\n[Common]\nAutoTrading=1" >> "$MT5/config/common.ini"
fi
sed -i 's/AutoTrading=0/AutoTrading=1/g' "$MT5/config/common.ini"
grep -i "AutoTrading\|AutoTr\|expert\|trading" "$MT5/config/common.ini" | head -5

# Step 4: Check Wine registry for MT5 settings
echo ""
echo "[4] Wine registry check:"
grep -i "autotrading\|metatrader\|mt5\|terminal64" /root/.wine/user.reg 2>/dev/null | head -10
grep -i "autotrading\|metatrader\|mt5\|terminal64" /root/.wine/system.reg 2>/dev/null | head -5

# Step 5: Start MT5 with explicit config
echo ""
echo "[5] Starting MT5 with config..."
cd "$MT5"
# Use the config parameter to force startup settings
screen -dmS mt5 bash -c "export DISPLAY=:99 && export WINEPREFIX=/root/.wine && cd \"$MT5\" && wine terminal64.exe /portable /config:\"C:\\\\Program Files\\\\MetaTrader 5\\\\config\\\\startup.ini\" 2>&1"
echo "  MT5 started with /config parameter"
sleep 20

# Step 6: Check if AutoTrading is now enabled
echo ""
echo "[6] Status check:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
echo "  AutoTrading log entries:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -5
echo "  Last EA entries:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -5

# Step 7: Also try sending WM_COMMAND via wine tool
echo ""
echo "[7] Try WM_COMMAND via Python/ctypes under Wine:"
cat > /tmp/enable_at.py << 'PYEOF'
import ctypes
import ctypes.wintypes

user32 = ctypes.windll.user32

def find_mt5_window():
    result = []
    def callback(hwnd, _):
        length = user32.GetWindowTextLengthW(hwnd)
        if length > 0:
            buf = ctypes.create_unicode_buffer(length + 1)
            user32.GetWindowTextW(hwnd, buf, length + 1)
            if 'FundedNext' in buf.value or 'MetaTrader' in buf.value:
                result.append((hwnd, buf.value))
        return True
    WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.wintypes.HWND, ctypes.wintypes.LPARAM)
    user32.EnumWindows(WNDENUMPROC(callback), 0)
    return result

windows = find_mt5_window()
for hwnd, name in windows:
    print(f"Found: {hwnd} = {name}")

if windows:
    hwnd = windows[0][0]
    # WM_COMMAND = 0x0111, AutoTrading toggle ID = 32842
    WM_COMMAND = 0x0111
    user32.PostMessageW(hwnd, WM_COMMAND, 32842, 0)
    print(f"Sent WM_COMMAND(32842) to {hwnd}")
PYEOF
wine python.exe /tmp/enable_at.py 2>/dev/null || echo "  Wine Python not available"

# Try with wine's built-in rundll32
echo ""
echo "[8] Alt: use xdotool with wmctrl focus:"
W=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
if [ -n "$W" ]; then
    wmctrl -i -a "$W" 2>/dev/null
    sleep 1
    xdotool key ctrl+e
    sleep 2
    cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -1
fi

echo "=== DONE $(date -u) ==="
