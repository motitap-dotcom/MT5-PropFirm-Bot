#!/bin/bash
# Enable AutoTrading via Windows-native SendKeys (VBScript under Wine)
echo "=== SENDKEYS FIX $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "[1] Pre-check AutoTrading state:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3

echo "[2] MT5 running:"
pgrep -a "start.exe\|terminal64" 2>/dev/null | head -3 || echo "Not running"
W=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
echo "  Window: $W"

# If MT5 not running, start it
if ! pgrep -f "terminal64\|start.exe" >/dev/null 2>&1; then
    echo "  Starting MT5..."
    cd "$MT5"
    screen -dmS mt5 bash -c "export DISPLAY=:99 && export WINEPREFIX=/root/.wine && wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server 2>&1"
    sleep 15
fi

echo "[3] Method 1: VBScript SendKeys (Windows-native)"
cat > /tmp/enable_autotrading.vbs << 'VBSEOF'
Set WshShell = WScript.CreateObject("WScript.Shell")
WScript.Sleep 500
result = WshShell.AppActivate("FundedNext")
WScript.Echo "AppActivate FundedNext: " & result
If Not result Then
    result = WshShell.AppActivate("MetaTrader")
    WScript.Echo "AppActivate MetaTrader: " & result
End If
If Not result Then
    result = WshShell.AppActivate("11797849")
    WScript.Echo "AppActivate 11797849: " & result
End If
WScript.Sleep 1000
WshShell.SendKeys "^e"
WScript.Echo "SendKeys ^e sent!"
WScript.Sleep 500
VBSEOF
wine cscript.exe //nologo "Z:\\tmp\\enable_autotrading.vbs" 2>&1
echo "  VBScript exit code: $?"

sleep 3
echo "[4] Post-VBScript check:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3

echo "[5] Method 2: Compile and run C program via MinGW"
# Check if MinGW/gcc is available under Wine
if [ -f "/root/.wine/drive_c/windows/system32/cmd.exe" ]; then
    # Create a small C program that sends WM_COMMAND
    cat > /tmp/enable_at.c << 'CEOF'
#include <windows.h>
#include <stdio.h>

BOOL CALLBACK EnumWindowsProc(HWND hwnd, LPARAM lParam) {
    char title[256];
    GetWindowTextA(hwnd, title, sizeof(title));
    if (strstr(title, "FundedNext") || strstr(title, "MetaTrader")) {
        printf("Found: %p = %s\n", hwnd, title);
        // WM_COMMAND with AutoTrading toggle ID
        PostMessage(hwnd, WM_COMMAND, 32842, 0);
        printf("Sent WM_COMMAND(32842) to %p\n", hwnd);
        *(HWND*)lParam = hwnd;
        return FALSE;  // Stop enumeration
    }
    return TRUE;
}

int main() {
    HWND found = NULL;
    EnumWindows(EnumWindowsProc, (LPARAM)&found);
    if (!found) {
        printf("No MT5 window found!\n");
        return 1;
    }
    Sleep(2000);
    return 0;
}
CEOF
    # Try to compile with MinGW if available
    which x86_64-w64-mingw32-gcc >/dev/null 2>&1 && {
        echo "  Compiling with MinGW..."
        x86_64-w64-mingw32-gcc -o /tmp/enable_at.exe /tmp/enable_at.c -luser32 2>&1
        if [ -f /tmp/enable_at.exe ]; then
            echo "  Running enable_at.exe..."
            wine /tmp/enable_at.exe 2>&1
            echo "  Exit code: $?"
        fi
    } || echo "  MinGW not available"
fi

# Check if apt can install mingw
echo ""
echo "[6] MinGW availability:"
which x86_64-w64-mingw32-gcc 2>/dev/null || dpkg -l | grep mingw 2>/dev/null | head -2 || echo "  Not installed"

sleep 3
echo "[7] Final check:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3
echo "  Last 3 EA entries:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -3

echo "=== DONE $(date -u) ==="
