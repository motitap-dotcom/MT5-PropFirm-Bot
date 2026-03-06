#!/bin/bash
# Enable AutoTrading via keybd_event ONLY (single toggle)
echo "=== KEYBD_EVENT FIX $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

cat > /tmp/at_keybd.c << 'CEOF'
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
        printf("No MT5 window found!\n");
        return 1;
    }

    // Focus the window
    SetForegroundWindow(g_found);
    Sleep(500);
    BringWindowToTop(g_found);
    Sleep(500);

    // Send Ctrl+E via keybd_event ONCE
    printf("Sending Ctrl+E via keybd_event...\n");
    keybd_event(VK_CONTROL, 0x1D, 0, 0);
    Sleep(50);
    keybd_event('E', 0x12, 0, 0);
    Sleep(50);
    keybd_event('E', 0x12, KEYEVENTF_KEYUP, 0);
    Sleep(50);
    keybd_event(VK_CONTROL, 0x1D, KEYEVENTF_KEYUP, 0);

    printf("Done! Single Ctrl+E sent.\n");
    Sleep(500);
    return 0;
}
CEOF

x86_64-w64-mingw32-gcc -o /tmp/at_keybd.exe /tmp/at_keybd.c -luser32 2>&1
cp /tmp/at_keybd.exe "/root/.wine/drive_c/at_keybd.exe"
cp /tmp/at_keybd.exe /root/at_keybd.exe

echo "[1] Pre-state:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3

echo "[2] Running keybd_event..."
wine "C:\\at_keybd.exe" 2>&1

sleep 5

echo "[3] Post-state:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -5
echo ""
echo "[4] Last 5 EA entries:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -5

echo "[5] Status:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null | head -12

echo "=== DONE $(date -u) ==="
