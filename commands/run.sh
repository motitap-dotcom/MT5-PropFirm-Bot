#!/bin/bash
# Improved AutoTrading enabler: try all windows + SendInput + multiple command IDs
echo "=== IMPROVED FIX $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# Create improved C program
cat > /tmp/enable_at2.c << 'CEOF'
#include <windows.h>
#include <stdio.h>

typedef struct {
    HWND windows[20];
    int count;
} WindowList;

BOOL CALLBACK EnumWindowsProc(HWND hwnd, LPARAM lParam) {
    WindowList* list = (WindowList*)lParam;
    char title[512];
    GetWindowTextA(hwnd, title, sizeof(title));
    if (strlen(title) > 5) {
        if (strstr(title, "FundedNext") != NULL ||
            strstr(title, "MetaTrader") != NULL) {
            if (list->count < 20) {
                list->windows[list->count] = hwnd;
                list->count++;
                printf("Window %d: %p = %s\n", list->count, (void*)hwnd, title);
            }
        }
    }
    return TRUE;
}

int main() {
    printf("=== AutoTrading Enabler v2 ===\n");

    WindowList list = {0};
    EnumWindows(EnumWindowsProc, (LPARAM)&list);
    printf("Found %d MT5 windows\n\n", list.count);

    if (list.count == 0) {
        printf("ERROR: No MT5 window found!\n");
        return 1;
    }

    // Method 1: Try WM_COMMAND with different IDs on ALL windows
    printf("--- Method 1: WM_COMMAND on all windows ---\n");
    int cmd_ids[] = {32842, 32843, 32844, 32910, 32909, 32908, 32911, 32912, 32906, 32905};
    int i, j;
    for (i = 0; i < list.count; i++) {
        // Try the most likely ID (32842) on each window
        printf("Sending WM_COMMAND(32842) to window %d (%p)...\n", i+1, (void*)list.windows[i]);
        SendMessage(list.windows[i], WM_COMMAND, MAKEWPARAM(32842, 0), 0);
        Sleep(500);
    }

    Sleep(2000);

    // Method 2: SetForegroundWindow + keybd_event (Ctrl+E)
    printf("\n--- Method 2: SetForegroundWindow + keybd_event ---\n");
    // Use the first (top-level) window
    HWND target = list.windows[0];
    printf("Targeting window: %p\n", (void*)target);

    // Try to set foreground
    SetForegroundWindow(target);
    Sleep(500);
    BringWindowToTop(target);
    Sleep(500);
    SetFocus(target);
    Sleep(500);

    // Send Ctrl+E via keybd_event
    printf("Sending Ctrl+E via keybd_event...\n");
    keybd_event(VK_CONTROL, 0x1D, 0, 0);
    Sleep(50);
    keybd_event('E', 0x12, 0, 0);
    Sleep(50);
    keybd_event('E', 0x12, KEYEVENTF_KEYUP, 0);
    Sleep(50);
    keybd_event(VK_CONTROL, 0x1D, KEYEVENTF_KEYUP, 0);

    Sleep(2000);

    // Method 3: SendInput (more modern API)
    printf("\n--- Method 3: SendInput ---\n");
    SetForegroundWindow(target);
    Sleep(500);

    INPUT inputs[4] = {0};
    // Ctrl down
    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.wVk = VK_CONTROL;
    // E down
    inputs[1].type = INPUT_KEYBOARD;
    inputs[1].ki.wVk = 'E';
    // E up
    inputs[2].type = INPUT_KEYBOARD;
    inputs[2].ki.wVk = 'E';
    inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;
    // Ctrl up
    inputs[3].type = INPUT_KEYBOARD;
    inputs[3].ki.wVk = VK_CONTROL;
    inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;

    UINT sent = SendInput(4, inputs, sizeof(INPUT));
    printf("SendInput sent %u events\n", sent);

    Sleep(2000);

    // Method 4: WM_KEYDOWN/WM_KEYUP directly to window
    printf("\n--- Method 4: WM_KEYDOWN/WM_KEYUP ---\n");
    for (i = 0; i < list.count; i++) {
        printf("Sending WM_KEYDOWN Ctrl+E to window %d...\n", i+1);
        PostMessage(list.windows[i], WM_KEYDOWN, VK_CONTROL, 0x001D0001);
        PostMessage(list.windows[i], WM_KEYDOWN, 'E', 0x00120001);
        Sleep(50);
        PostMessage(list.windows[i], WM_KEYUP, 'E', 0xC0120001);
        PostMessage(list.windows[i], WM_KEYUP, VK_CONTROL, 0xC01D0001);
        Sleep(1000);
    }

    printf("\nAll methods tried!\n");
    Sleep(1000);
    return 0;
}
CEOF

echo "[1] Compiling..."
x86_64-w64-mingw32-gcc -o /tmp/enable_at2.exe /tmp/enable_at2.c -luser32 2>&1
cp /tmp/enable_at2.exe "/root/.wine/drive_c/enable_at2.exe"
echo "  Done"

echo "[2] Running..."
wine "C:\\enable_at2.exe" 2>&1

echo "[3] Check result:"
sleep 2
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
echo "  AutoTrading entries:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -5
echo "  Last 5 EA entries:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -5

echo "=== DONE $(date -u) ==="
