#!/bin/bash
# =============================================================
# Fix ALL issues: Update EA, Fix Telegram WebRequest, Restart MT5
# =============================================================

echo "=== FULL FIX SCRIPT - $(date) ==="
echo ""

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
CONFIG_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"

# ============================================
# STEP 1: Fix Telegram WebRequest in MT5 config
# ============================================
echo "--- STEP 1: Fix Telegram WebRequest ---"

# Find MT5 terminal config
TERMINAL_INI="${MT5_BASE}/config/common.ini"
if [ ! -f "$TERMINAL_INI" ]; then
    # Try alternate locations
    TERMINAL_INI=$(find "$MT5_BASE" -name "common.ini" 2>/dev/null | head -1)
fi

if [ -f "$TERMINAL_INI" ]; then
    echo "Found config: $TERMINAL_INI"
    cat "$TERMINAL_INI"
    echo ""

    # Check if WebRequest URL already exists
    if grep -q "api.telegram.org" "$TERMINAL_INI" 2>/dev/null; then
        echo "Telegram WebRequest already configured!"
    else
        echo "Adding Telegram WebRequest URL..."
        # Add WebRequest settings
        if grep -q "\[Experts\]" "$TERMINAL_INI" 2>/dev/null; then
            # Section exists, add URL
            sed -i '/\[Experts\]/a AllowWebRequest=1\nWebRequestUrl1=https://api.telegram.org' "$TERMINAL_INI"
        else
            # Add section
            echo -e "\n[Experts]\nAllowWebRequest=1\nWebRequestUrl1=https://api.telegram.org" >> "$TERMINAL_INI"
        fi
        echo "WebRequest URL added!"
    fi
else
    echo "common.ini not found, searching for all config files..."
    find "$MT5_BASE" -name "*.ini" -type f 2>/dev/null
fi

# Also check terminal64.ini
TERM64_INI=$(find "$MT5_BASE" -name "terminal64.ini" 2>/dev/null | head -1)
if [ -f "$TERM64_INI" ]; then
    echo ""
    echo "Found terminal64.ini: $TERM64_INI"
    if ! grep -q "api.telegram.org" "$TERM64_INI" 2>/dev/null; then
        if grep -q "\[Experts\]" "$TERM64_INI" 2>/dev/null; then
            sed -i '/\[Experts\]/a AllowWebRequest=1\nWebRequestUrl1=https://api.telegram.org' "$TERM64_INI"
        else
            echo -e "\n[Experts]\nAllowWebRequest=1\nWebRequestUrl1=https://api.telegram.org" >> "$TERM64_INI"
        fi
        echo "WebRequest added to terminal64.ini!"
    else
        echo "Already configured in terminal64.ini"
    fi
fi

echo ""

# ============================================
# STEP 2: Backup current EA
# ============================================
echo "--- STEP 2: Backup current EA ---"
if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
    cp "$EA_DIR/PropFirmBot.ex5" "$EA_DIR/PropFirmBot.ex5.bak_before_param_fix"
    echo "Backup created"
else
    echo "No .ex5 to backup"
fi
echo ""

# ============================================
# STEP 3: Kill MT5, Recompile, Restart
# ============================================
echo "--- STEP 3: Kill MT5 ---"
# Kill any running MT5
pkill -f terminal64 2>/dev/null || true
pkill -f metatrader 2>/dev/null || true
# Kill wine MT5 processes
pkill -f "MetaTrader" 2>/dev/null || true
sleep 2

# Verify killed
if pgrep -f "terminal64\|metatrader\|MetaTrader" > /dev/null 2>&1; then
    echo "Force killing MT5..."
    pkill -9 -f "terminal64\|metatrader\|MetaTrader" 2>/dev/null || true
    sleep 2
fi
echo "MT5 stopped"
echo ""

echo "--- STEP 4: Recompile EA ---"
cd "$EA_DIR"
WINEPREFIX=/root/.wine wine "$MT5_BASE/metaeditor64.exe" /compile:PropFirmBot.mq5 /log 2>/dev/null || true
sleep 5

# Check compilation result
if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
    NEW_SIZE=$(stat -c%s "$EA_DIR/PropFirmBot.ex5" 2>/dev/null)
    echo "Compilation OK! New .ex5 size: $NEW_SIZE bytes"
    echo "File date: $(ls -la "$EA_DIR/PropFirmBot.ex5")"
else
    echo "ERROR: Compilation failed! No .ex5 file found"
fi

# Check compile log
if [ -f "$EA_DIR/PropFirmBot.log" ]; then
    echo "Compile log:"
    cat "$EA_DIR/PropFirmBot.log"
fi
echo ""

echo "--- STEP 5: Restart MT5 ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# Start MT5
cd "$MT5_BASE"
nohup wine "$MT5_BASE/terminal64.exe" /portable > /dev/null 2>&1 &
MT5_PID=$!
echo "MT5 started with PID: $MT5_PID"

# Wait for MT5 to load
echo "Waiting for MT5 to start..."
sleep 15

# Check if MT5 is running
if pgrep -f "terminal64" > /dev/null 2>&1; then
    echo "MT5 is RUNNING!"
else
    # Check wine processes
    WINE_PROCS=$(pgrep -a -f "wine\|MT5\|MetaTrader" 2>/dev/null)
    if [ -n "$WINE_PROCS" ]; then
        echo "MT5 running as wine process:"
        echo "$WINE_PROCS"
    else
        echo "WARNING: MT5 may not have started"
    fi
fi
echo ""

# ============================================
# STEP 6: Verify everything
# ============================================
echo "--- STEP 6: Full Verification ---"

echo "Processes:"
pgrep -a -f "terminal64\|metatrader\|MetaTrader\|wine.*exe" 2>/dev/null | head -10
echo ""

echo "VNC status:"
pgrep -a x11vnc 2>/dev/null || echo "x11vnc NOT running!"
echo ""

echo "EA files:"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
echo ""

echo "Config files:"
ls -la "$CONFIG_DIR/" 2>/dev/null
echo ""

echo "Network connections (MT5):"
sleep 10
ss -tnp | grep -i "wine\|terminal\|metatrader\|main" | head -10
echo ""

# Wait a bit more for EA to initialize then check logs
echo "Waiting for EA to initialize..."
sleep 20

echo "--- EA Logs (after restart) ---"
MT5_LOG_DIR="${MT5_BASE}/MQL5/Logs"
LATEST_LOG=$(ls -t "$MT5_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -f "$LATEST_LOG" ]; then
    echo "Log file: $LATEST_LOG"
    tail -40 "$LATEST_LOG"
else
    echo "No EA logs found yet"
fi
echo ""

echo "--- Status JSON ---"
cat "$CONFIG_DIR/status.json" 2>/dev/null || echo "No status.json"
echo ""

echo "=== DONE - $(date) ==="
