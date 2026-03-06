#!/bin/bash
# Reproduce EXACT sequence that worked: WM_COMMAND + keybd_event
echo "=== EXACT SEQUENCE $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

cat > /tmp/at_exact.c << 'CEOF'
#include <windows.h>
#include <stdio.h>

HWND g_found = NULL;

BOOL CALLBACK EnumWindowsProc(HWND hwnd, LPARAM lParam) {
    char title[512];
    GetWindowTextA(hwnd, title, sizeof(title));
    if (strstr(title, "FundedNext") != NULL || strstr(title, "MetaTrader") != NULL) {
        if (g_found == NULL) {
            g_found = hwnd;
            printf("Found: %p = %s\n", (void*)hwnd, title);
        }
    }
    return TRUE;
}

int main() {
    EnumWindows(EnumWindowsProc, 0);
    if (!g_found) {
        printf("No MT5 window!\n");
        return 1;
    }

    // Step 1: WM_COMMAND as priming (same as v2 Method 1)
    printf("Step 1: WM_COMMAND(32842) priming...\n");
    SendMessage(g_found, WM_COMMAND, MAKEWPARAM(32842, 0), 0);
    Sleep(2500);

    // Step 2: Full focus sequence + keybd_event (same as v2 Method 2)
    printf("Step 2: Focus + keybd_event Ctrl+E...\n");
    SetForegroundWindow(g_found);
    Sleep(500);
    BringWindowToTop(g_found);
    Sleep(500);
    SetFocus(g_found);
    Sleep(500);

    keybd_event(VK_CONTROL, 0x1D, 0, 0);
    Sleep(50);
    keybd_event('E', 0x12, 0, 0);
    Sleep(50);
    keybd_event('E', 0x12, KEYEVENTF_KEYUP, 0);
    Sleep(50);
    keybd_event(VK_CONTROL, 0x1D, KEYEVENTF_KEYUP, 0);

    printf("Done! Waiting for toggle...\n");
    Sleep(3000);
    return 0;
}
CEOF

x86_64-w64-mingw32-gcc -o /tmp/at_exact.exe /tmp/at_exact.c -luser32 2>&1
cp /tmp/at_exact.exe "/root/.wine/drive_c/at_exact.exe"

echo "[1] Pre-state:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3

echo "[2] Running exact sequence..."
wine "C:\\at_exact.exe" 2>&1

echo "[3] Post-state:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -5
echo "[4] Last 5 EA entries:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -5

echo "=== DONE $(date -u) ==="
