#!/bin/bash
# =============================================================
# Compile EA - multiple methods - 2026-03-04
# =============================================================

echo "=== Compile EA - $(date) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. Stop MT5
echo "--- Stopping MT5 ---"
pkill -f terminal64 2>/dev/null
sleep 5
pkill -9 -f terminal64 2>/dev/null
sleep 2
echo "MT5 stopped"

# 2. Record old .ex5 hash
OLD_HASH=$(md5sum "$EA_DIR/PropFirmBot.ex5" 2>/dev/null | cut -d' ' -f1)
echo "Old .ex5 hash: $OLD_HASH"

# 3. Try MetaEditor with Windows-style path
echo ""
echo "--- Method 1: MetaEditor with Windows path ---"
wine "$MT5/metaeditor64.exe" /compile:"MQL5\\Experts\\PropFirmBot\\PropFirmBot.mq5" /log 2>&1 | head -20
sleep 8

NEW_HASH=$(md5sum "$EA_DIR/PropFirmBot.ex5" 2>/dev/null | cut -d' ' -f1)
echo "After method 1 hash: $NEW_HASH"
if [ "$OLD_HASH" != "$NEW_HASH" ]; then
    echo "SUCCESS! .ex5 changed!"
else
    echo "No change. Trying method 2..."

    # 4. Method 2: full Windows path
    echo ""
    echo "--- Method 2: Full absolute Windows path ---"
    cd "$MT5"
    wine metaeditor64.exe "/compile:MQL5\Experts\PropFirmBot\PropFirmBot.mq5" /log 2>&1 | head -20
    sleep 8

    NEW_HASH=$(md5sum "$EA_DIR/PropFirmBot.ex5" 2>/dev/null | cut -d' ' -f1)
    echo "After method 2 hash: $NEW_HASH"
    if [ "$OLD_HASH" != "$NEW_HASH" ]; then
        echo "SUCCESS! .ex5 changed!"
    else
        echo "No change. Trying method 3..."

        # 5. Method 3: delete .ex5 and use metaeditor with /s flag
        echo ""
        echo "--- Method 3: Delete .ex5 + recompile ---"
        rm -f "$EA_DIR/PropFirmBot.ex5"
        cd "$MT5"
        wine metaeditor64.exe /compile:"C:\\Program Files\\MetaTrader 5\\MQL5\\Experts\\PropFirmBot\\PropFirmBot.mq5" /log 2>&1 | head -20
        sleep 10

        if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
            NEW_HASH=$(md5sum "$EA_DIR/PropFirmBot.ex5" 2>/dev/null | cut -d' ' -f1)
            echo "NEW .ex5 created! Hash: $NEW_HASH"
            echo "SUCCESS!"
        else
            echo "Still no .ex5. Trying method 4..."

            # 6. Method 4: restore backup and try compiling via xdotool
            echo ""
            echo "--- Method 4: Restore .ex5 backup, start MT5, use xdotool ---"
            cp "$EA_DIR/PropFirmBot.ex5.before_update" "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || \
            cp "$EA_DIR/PropFirmBot.ex5.bak" "$EA_DIR/PropFirmBot.ex5" 2>/dev/null

            # Install xdotool if not present
            which xdotool > /dev/null 2>&1 || apt-get install -y -qq xdotool > /dev/null 2>&1

            # Start MT5
            cd "$MT5"
            wine terminal64.exe /portable &
            sleep 20

            # Use xdotool to press F4 (open MetaEditor), wait, compile, close
            echo "Sending F4 to open MetaEditor..."
            xdotool key F4
            sleep 10
            echo "Sending F7 to compile..."
            xdotool key F7
            sleep 10
            echo "Sending Alt+F4 to close MetaEditor..."
            xdotool key alt+F4
            sleep 5

            NEW_HASH=$(md5sum "$EA_DIR/PropFirmBot.ex5" 2>/dev/null | cut -d' ' -f1)
            echo "After method 4 hash: $NEW_HASH"
            if [ "$OLD_HASH" != "$NEW_HASH" ]; then
                echo "SUCCESS!"
            else
                echo "FAILED all methods. Manual compile needed via VNC."
            fi
        fi
    fi
fi

# 7. Start MT5 if not already running
if ! ps aux | grep -q "[t]erminal64"; then
    echo ""
    echo "--- Starting MT5 ---"
    cd "$MT5"
    wine terminal64.exe /portable &
    sleep 15
fi

# 8. Final status
echo ""
echo "=== FINAL STATUS ==="
ps aux | grep "[t]erminal64" | head -2
echo ""
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
echo ""
FINAL_HASH=$(md5sum "$EA_DIR/PropFirmBot.ex5" 2>/dev/null | cut -d' ' -f1)
echo "Original hash: $OLD_HASH"
echo "Final hash:    $FINAL_HASH"
if [ "$OLD_HASH" != "$FINAL_HASH" ]; then
    echo "COMPILATION SUCCESSFUL - new binary loaded!"
else
    echo "WARNING: Same binary - compile did not work"
fi

echo ""
echo "=== Done ==="
