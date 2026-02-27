#!/bin/bash
# Fix Wine networking + MT5 connection
echo "=== FIX WINE NETWORK + MT5 $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

echo ""
echo "--- 1. Kill everything ---"
pkill -f terminal64.exe 2>/dev/null; sleep 2
wineserver -k 2>/dev/null; sleep 3
pkill -9 -f wine 2>/dev/null; sleep 2

echo ""
echo "--- 2. Check Wine networking DLLs ---"
echo "winhttp.dll:"
ls -la /root/.wine/drive_c/windows/system32/winhttp.dll 2>/dev/null || echo "  MISSING!"
echo "wininet.dll:"
ls -la /root/.wine/drive_c/windows/system32/wininet.dll 2>/dev/null || echo "  MISSING!"
echo "ws2_32.dll:"
ls -la /root/.wine/drive_c/windows/system32/ws2_32.dll 2>/dev/null || echo "  MISSING!"
echo "crypt32.dll:"
ls -la /root/.wine/drive_c/windows/system32/crypt32.dll 2>/dev/null || echo "  MISSING!"
echo "secur32.dll:"
ls -la /root/.wine/drive_c/windows/system32/secur32.dll 2>/dev/null || echo "  MISSING!"

echo ""
echo "--- 3. Check DLL overrides ---"
wine reg query "HKCU\\Software\\Wine\\DllOverrides" 2>/dev/null || echo "No overrides"

echo ""
echo "--- 4. Test Wine HTTPS connectivity ---"
echo "Testing with Wine wget..."
wine wget --timeout=5 -O /dev/null "https://www.google.com" 2>&1 | head -5 || echo "wget not available"

echo ""
echo "Testing with Wine certutil..."
wine certutil -urlcache -split -f "https://www.google.com" /dev/null 2>&1 | head -5 || echo "certutil failed"

echo ""
echo "--- 5. Check settings.ini ---"
cat "$MT5/config/settings.ini" | tr -d '\0' 2>/dev/null

echo ""
echo "--- 6. Create MT5 startup config file ---"
# Create a config file that forces login
cat > /tmp/mt5_startup.ini << 'CONF'
[Common]
Login=11797849
Server=FundedNext-Server
CertInstall=0
ProxyEnable=0
NewsEnable=0
[StartUp]
Expert=PropFirmBot\PropFirmBot
ExpertParameters=
Symbol=EURUSD
Period=M15
[Experts]
AllowLiveTrading=1
AllowDllImport=0
Enabled=1
Account=1
Profile=0
Chart=0
CONF

echo "Created /tmp/mt5_startup.ini"

echo ""
echo "--- 7. Start MT5 with WINEDEBUG for network diagnosis ---"
cd "$MT5"

# First, try with WINEDEBUG to capture network-related errors
WINEDEBUG=+winsock,+winhttp,+wininet timeout 30 wine terminal64.exe /config:"Z:\\tmp\\mt5_startup.ini" /login:11797849 /password:"gazDE62##" /server:FundedNext-Server > /tmp/wine_net_debug.log 2>&1 &
WINE_PID=$!
echo "MT5 started with debug, PID: $WINE_PID, waiting 25s..."
sleep 25

# Save debug output
echo ""
echo "Wine network debug (last 50 lines):"
tail -50 /tmp/wine_net_debug.log 2>/dev/null

# Kill this debug run
kill $WINE_PID 2>/dev/null
wineserver -k 2>/dev/null
sleep 5

echo ""
echo "--- 8. Check if DNS works from Wine ---"
echo "Wine nslookup:"
wine cmd /c "nslookup 8.8.8.8" 2>&1 | head -10

echo ""
echo "--- 9. Wine socket test ---"
# Create a simple test to see if Wine can open TCP connections
cat > /tmp/test_connect.bat << 'BAT'
@echo off
echo Testing connection...
ping -n 1 8.8.8.8
BAT
wine cmd /c "Z:\\tmp\\test_connect.bat" 2>&1 | head -10

echo ""
echo "--- 10. Check if firewall blocks MT5 ---"
# Check iptables for any MT5-specific rules
iptables -L -n -v 2>/dev/null | head -30

echo ""
echo "--- 11. Start MT5 CLEAN (no debug, with config file) ---"
wineserver -k 2>/dev/null; sleep 3

# Copy config to MT5 directory
cp /tmp/mt5_startup.ini "$MT5/config/common.ini"
echo "Updated common.ini with fresh config"

cd "$MT5"
nohup wine terminal64.exe /login:11797849 /password:"gazDE62##" /server:FundedNext-Server </dev/null > /tmp/mt5_final.log 2>&1 &
disown -a
echo "MT5 started, waiting 90s..."
sleep 90

echo ""
echo "--- 12. Final check ---"
PID=$(pgrep -f terminal64.exe 2>/dev/null | head -1)
echo "MT5 PID: $PID"
echo ""
echo "Terminal log:"
TLOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
[ -n "$TLOG" ] && cat "$TLOG" | tr -d '\0' | tail -20

echo ""
echo "EA log:"
TODAY=$(date '+%Y%m%d')
EALOG="$MT5/MQL5/Logs/${TODAY}.log"
[ -f "$EALOG" ] && cat "$EALOG" | tr -d '\0' | tail -20 || echo "No EA log"

echo ""
echo "Outbound connections:"
ss -tn state established | grep -v ":22 \|:5900 \|:53 " | head -10

echo ""
echo "Wine final log:"
tail -30 /tmp/mt5_final.log 2>/dev/null

echo ""
echo "=== DONE ==="
