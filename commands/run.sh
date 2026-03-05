#!/bin/bash
# =============================================================
# Fix #2: Delete saved state + Fix WebRequest via registry + Restart
# =============================================================

echo "=== FIX #2 - $(date) ==="
echo ""

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"

# ============================================
# STEP 1: Kill MT5
# ============================================
echo "--- STEP 1: Kill MT5 ---"
pkill -9 -f "terminal64\|metatrader\|MetaTrader" 2>/dev/null || true
sleep 3
echo "MT5 stopped"
echo ""

# ============================================
# STEP 2: Delete saved state file (forces reload from new defaults)
# ============================================
echo "--- STEP 2: Delete saved state file ---"
COMMON_FILES="/root/.wine/drive_c/users/root/Application Data/MetaQuotes/Terminal/Common/Files"
STATE_FILE=$(find "$COMMON_FILES" -name "PropFirmBot_AccountState.dat" 2>/dev/null)
if [ -n "$STATE_FILE" ]; then
    echo "Found state file: $STATE_FILE"
    rm -f "$STATE_FILE"
    echo "DELETED - EA will use new defaults on restart"
else
    echo "No state file found in common files"
    # Search everywhere
    find /root/.wine -name "PropFirmBot_AccountState.dat" 2>/dev/null | while read f; do
        echo "Found: $f - deleting..."
        rm -f "$f"
    done
fi
echo ""

# ============================================
# STEP 3: Fix Telegram WebRequest in common.ini
# ============================================
echo "--- STEP 3: Fix Telegram WebRequest ---"
COMMON_INI="${MT5_BASE}/config/common.ini"

if [ -f "$COMMON_INI" ]; then
    echo "Current common.ini:"
    cat "$COMMON_INI"
    echo ""

    # Remove any previous broken WebRequest additions
    sed -i '/AllowWebRequest/d' "$COMMON_INI"
    sed -i '/WebRequestUrl/d' "$COMMON_INI"

    # Add WebRequest properly under [Experts] section
    # MT5 format: AllowWebRequest=1 and WebRequestUrl1=url
    python3 -c "
import configparser
import io

# Read the file
with open('$COMMON_INI', 'r') as f:
    content = f.read()

# Parse it
config = configparser.ConfigParser()
config.optionxform = str  # Keep case
config.read_string(content)

# Ensure [Experts] section has WebRequest
if 'Experts' not in config:
    config['Experts'] = {}

config['Experts']['AllowWebRequest'] = '1'
config['Experts']['WebRequestUrl1'] = 'https://api.telegram.org'

# Write back
with open('$COMMON_INI', 'w') as f:
    config.write(f, space_around_delimiters=False)
" 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "Python configparser failed, using manual approach..."
        # Manual: ensure the right format
        # Remove existing [Experts] section content and recreate
        sed -i '/^\[Experts\]/,/^\[/{/^\[Experts\]/!{/^\[/!d}}' "$COMMON_INI"
        sed -i 's/\[Experts\]/[Experts]\nAllowLiveTrading=1\nAllowDllImport=0\nEnabled=1\nAccount=11797849\nProfile=0\nAllowWebRequest=1\nWebRequestUrl1=https:\/\/api.telegram.org/' "$COMMON_INI"
    fi

    echo ""
    echo "Updated common.ini:"
    cat "$COMMON_INI"
fi
echo ""

# ============================================
# STEP 4: Also try Wine registry for WebRequest
# ============================================
echo "--- STEP 4: Wine registry WebRequest ---"
# Find MT5 terminal hash directory
TERMINAL_DIRS=$(find /root/.wine/drive_c/users -path "*/MetaQuotes/Terminal/*/origin.txt" 2>/dev/null | head -5)
for origin in $TERMINAL_DIRS; do
    TERM_DIR=$(dirname "$origin")
    echo "Terminal dir: $TERM_DIR"

    # Check for terminal.ini
    if [ -f "$TERM_DIR/config/terminal.ini" ]; then
        echo "Found terminal.ini"
        grep -i "webrequest\|AllowWebRequest" "$TERM_DIR/config/terminal.ini" || echo "No WebRequest in terminal.ini"
    fi
done
echo ""

# ============================================
# STEP 5: Recompile EA with updated AccountStateManager
# ============================================
echo "--- STEP 5: Recompile EA ---"
cd "$EA_DIR"
WINEPREFIX=/root/.wine wine "$MT5_BASE/metaeditor64.exe" /compile:PropFirmBot.mq5 /log 2>/dev/null || true
sleep 5

if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
    echo "Compilation OK! Size: $(stat -c%s "$EA_DIR/PropFirmBot.ex5") bytes"
else
    echo "ERROR: Compilation failed!"
fi

# Check for errors in compile log
if [ -f "$EA_DIR/PropFirmBot.log" ]; then
    grep -i "error" "$EA_DIR/PropFirmBot.log" | head -5 || echo "No errors in compile log"
fi
echo ""

# ============================================
# STEP 6: Restart MT5
# ============================================
echo "--- STEP 6: Restart MT5 ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

cd "$MT5_BASE"
nohup wine "$MT5_BASE/terminal64.exe" /portable > /dev/null 2>&1 &
echo "MT5 started, waiting 25 seconds for initialization..."
sleep 25

# ============================================
# STEP 7: Full verification
# ============================================
echo "--- STEP 7: Verification ---"

echo "MT5 processes:"
pgrep -a -f "terminal64\|wine.*exe" 2>/dev/null | head -5
echo ""

echo "VNC status:"
pgrep -a x11vnc 2>/dev/null || echo "x11vnc NOT running!"
echo ""

echo "Network connections:"
ss -tnp | grep -i "wine\|terminal\|main" | head -5
echo ""

echo "--- EA Logs (checking for new params) ---"
MT5_LOG_DIR="${MT5_BASE}/MQL5/Logs"
LATEST_LOG=$(ls -t "$MT5_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -f "$LATEST_LOG" ]; then
    echo "Log file: $LATEST_LOG"
    # Show last 60 lines for full init sequence
    tail -60 "$LATEST_LOG" | strings
else
    echo "No logs found"
fi
echo ""

echo "--- Status JSON ---"
cat "${MT5_BASE}/MQL5/Files/PropFirmBot/status.json" 2>/dev/null || echo "No status.json"
echo ""

echo "=== DONE - $(date) ==="
