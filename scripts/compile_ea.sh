#!/bin/bash
# Fix MetaEditor dependency and compile PropFirmBot EA
set -x
export DISPLAY=:99
export WINEPREFIX=/root/.wine

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
EDITOR="$MT5/MetaEditor64.exe"

echo "=== EA Compilation $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="

# Show initial state
echo "--- Current .ex5 ---"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
BEFORE_TIME=$(stat -c%Y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo 0)

# Stop MT5
echo "--- Stopping MT5 ---"
pkill -f terminal64 2>/dev/null || true
sleep 3

# Step 1: Install dbghelp.dll (required by MetaEditor)
echo ""
echo "--- Installing dbghelp.dll ---"
if command -v winetricks > /dev/null 2>&1; then
    echo "winetricks found, installing dbghelp..."
    winetricks -q dbghelp 2>&1 || echo "winetricks dbghelp failed, trying manual..."
else
    echo "winetricks not found, installing..."
    apt-get update -qq && apt-get install -y -qq winetricks > /dev/null 2>&1 || true
    if command -v winetricks > /dev/null 2>&1; then
        winetricks -q dbghelp 2>&1 || echo "winetricks dbghelp failed"
    else
        echo "Could not install winetricks, trying manual DLL override..."
    fi
fi

# Manual override: tell Wine to use builtin dbghelp
echo "Setting Wine DLL override for dbghelp..."
wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v dbghelp /d builtin /f 2>/dev/null || true

# Also check if native dbghelp exists in system32
echo "Checking system32 for dbghelp.dll..."
ls -la /root/.wine/drive_c/windows/system32/dbghelp.dll 2>/dev/null || echo "Not in system32"
ls -la "$MT5/dbghelp.dll" 2>/dev/null || echo "Not in MT5 dir"

# Step 2: Try MetaEditor compilation
echo ""
echo "--- Compiling with MetaEditor ---"
if [ -f "$EDITOR" ]; then
    cd "$EA_DIR"
    # Use Windows-style path for /compile argument
    timeout 45 wine "$EDITOR" /compile:"C:\Program Files\MetaTrader 5\MQL5\Experts\PropFirmBot\PropFirmBot.mq5" /log 2>&1
    COMPILE_EXIT=$?
    echo "MetaEditor exit code: $COMPILE_EXIT"
    sleep 3

    # Check for compilation log
    for logfile in "$EA_DIR/"*.log "$MT5/MQL5/"*.log; do
        if [ -f "$logfile" ] 2>/dev/null; then
            echo "Log: $logfile"
            cat "$logfile" 2>/dev/null | tr -d '\0' | tail -20
            echo "---"
        fi
    done

    # Check if .ex5 updated
    AFTER_TIME=$(stat -c%Y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo 0)
    if [ "$AFTER_TIME" -gt "$BEFORE_TIME" ]; then
        echo "SUCCESS: .ex5 was recompiled!"
        ls -la "$EA_DIR/PropFirmBot.ex5"
    else
        echo "MetaEditor didn't update .ex5"
        echo ""
        echo "--- Fallback: Remove .ex5 and let MT5 auto-compile ---"
        mv "$EA_DIR/PropFirmBot.ex5" "$EA_DIR/PropFirmBot.ex5.old" 2>/dev/null
        echo "Old .ex5 moved to .ex5.old"
    fi
else
    echo "MetaEditor not found at: $EDITOR"
    echo "--- Fallback: Remove .ex5 ---"
    mv "$EA_DIR/PropFirmBot.ex5" "$EA_DIR/PropFirmBot.ex5.old" 2>/dev/null
fi

# Step 3: Start MT5
echo ""
echo "--- Starting MT5 ---"
pkill -f terminal64 2>/dev/null || true
sleep 2
cd "$MT5"
nohup wine terminal64.exe > /dev/null 2>&1 &
disown

echo "Waiting 15s for MT5 to start..."
sleep 15

# Check if MT5 created a new .ex5
if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
    FINAL_TIME=$(stat -c%Y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo 0)
    echo "FINAL .ex5:"
    ls -la "$EA_DIR/PropFirmBot.ex5"
    if [ "$FINAL_TIME" -gt "$BEFORE_TIME" ]; then
        echo ">>> NEW .ex5 COMPILED SUCCESSFULLY! <<<"
    else
        echo "WARNING: .ex5 has old timestamp"
    fi
else
    echo ".ex5 does not exist!"
    if [ -f "$EA_DIR/PropFirmBot.ex5.old" ]; then
        echo "Restoring old .ex5 as fallback..."
        mv "$EA_DIR/PropFirmBot.ex5.old" "$EA_DIR/PropFirmBot.ex5"
    fi
fi

# Verify MT5 running
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "MT5 running OK"
else
    echo "MT5 NOT running - starting again..."
    cd "$MT5"
    nohup wine terminal64.exe > /dev/null 2>&1 &
    disown
    sleep 8
fi

echo ""
echo "=== DONE ==="
