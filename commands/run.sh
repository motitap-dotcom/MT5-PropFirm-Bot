#!/bin/bash
# Send WM_COMMAND(32842) ONCE to enable AutoTrading
echo "=== SINGLE TOGGLE $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# Create minimal C program - SINGLE WM_COMMAND only
cat > /tmp/toggle_at.c << 'CEOF'
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
    // Send EXACTLY ONE WM_COMMAND(32842) toggle
    SendMessage(g_found, WM_COMMAND, MAKEWPARAM(32842, 0), 0);
    printf("WM_COMMAND(32842) sent ONCE to %p\n", (void*)g_found);
    return 0;
}
CEOF

x86_64-w64-mingw32-gcc -o /tmp/toggle_at.exe /tmp/toggle_at.c -luser32 2>&1
cp /tmp/toggle_at.exe "/root/.wine/drive_c/toggle_at.exe"
cp /tmp/toggle_at.exe /root/toggle_at.exe

echo "[1] Pre-state:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3

echo "[2] Sending single toggle..."
wine "C:\\toggle_at.exe" 2>&1

sleep 3

echo "[3] Post-state:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3
echo "[4] Last EA entries:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -8

echo "[5] Bot status:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null | head -12

echo "=== DONE $(date -u) ==="
