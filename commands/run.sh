#!/bin/bash
# Install MinGW, compile WM_COMMAND sender, enable AutoTrading
echo "=== MINGW APPROACH $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# Step 1: Install MinGW cross-compiler
echo "[1] Installing MinGW..."
apt-get install -y -qq gcc-mingw-w64-x86-64 2>/dev/null | tail -3
which x86_64-w64-mingw32-gcc && echo "  MinGW installed!" || echo "  FAILED"

# Step 2: Create the C program
echo "[2] Creating WM_COMMAND sender..."
cat > /tmp/enable_autotrading.c << 'CEOF'
#include <windows.h>
#include <stdio.h>

BOOL CALLBACK EnumWindowsProc(HWND hwnd, LPARAM lParam) {
    char title[512];
    GetWindowTextA(hwnd, title, sizeof(title));
    if (strlen(title) > 0) {
        if (strstr(title, "FundedNext") != NULL ||
            strstr(title, "MetaTrader") != NULL ||
            strstr(title, "11797849") != NULL) {
            printf("Found window: %p = %s\n", (void*)hwnd, title);

            // Send WM_COMMAND with AutoTrading toggle command ID (32842)
            // This is the same as clicking the AutoTrading button
            LRESULT result = SendMessage(hwnd, WM_COMMAND, MAKEWPARAM(32842, 0), 0);
            printf("SendMessage WM_COMMAND(32842) result: %ld\n", (long)result);

            // Also try PostMessage
            PostMessage(hwnd, WM_COMMAND, MAKEWPARAM(32842, 0), 0);
            printf("PostMessage WM_COMMAND(32842) sent\n");

            *(int*)lParam = 1;
            return FALSE; // Found it, stop
        }
    }
    return TRUE;
}

int main() {
    printf("Searching for MT5 window...\n");
    int found = 0;
    EnumWindows(EnumWindowsProc, (LPARAM)&found);

    if (!found) {
        printf("ERROR: No MT5 window found!\n");
        return 1;
    }

    printf("Done! AutoTrading toggle command sent.\n");
    Sleep(1000);
    return 0;
}
CEOF

# Step 3: Compile
echo "[3] Compiling..."
x86_64-w64-mingw32-gcc -o /tmp/enable_autotrading.exe /tmp/enable_autotrading.c -luser32 2>&1
[ -f /tmp/enable_autotrading.exe ] && echo "  Compiled OK!" || { echo "  COMPILE FAILED"; exit 1; }

# Copy to wine-accessible path
cp /tmp/enable_autotrading.exe "/root/.wine/drive_c/enable_autotrading.exe"

# Step 4: Make sure MT5 is running
echo "[4] MT5 check:"
if ! pgrep -f "terminal64\|start.exe" >/dev/null 2>&1; then
    echo "  Starting MT5..."
    cd "$MT5"
    screen -dmS mt5 bash -c "export DISPLAY=:99 && export WINEPREFIX=/root/.wine && wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server 2>&1"
    sleep 15
fi
pgrep -a "start.exe\|terminal64" 2>/dev/null | head -2

# Step 5: Run the AutoTrading enabler
echo "[5] Running AutoTrading enabler..."
wine "C:\\enable_autotrading.exe" 2>&1

sleep 3

# Step 6: Check result
echo "[6] Result:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
echo "  AutoTrading log:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -5
echo "  Last 5 EA entries:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -5

# Save the exe for future use
cp /tmp/enable_autotrading.exe /root/enable_autotrading.exe 2>/dev/null

echo "=== DONE $(date -u) ==="
