#!/bin/bash
# Find correct FundedNext server config and fix connection
echo "=== SERVER DIAGNOSIS $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. Find all server config files
echo "--- 1. Server config files (.dat/.srv) ---"
find "$MT5" -name "*.dat" -o -name "*.srv" 2>/dev/null | head -30
echo ""
echo "Config directory:"
ls -laR "$MT5/config/" 2>&1

# 2. Check the server directory
echo ""
echo "--- 2. Servers directory ---"
if [ -d "$MT5/config/servers" ]; then
    ls -la "$MT5/config/servers/"
fi

# 3. Check origin directory (where MT5 stores server data)
echo ""
echo "--- 3. Origin directory ---"
if [ -d "$MT5/origin" ]; then
    ls -laR "$MT5/origin/" 2>&1
fi

# 4. Check any cached server info
echo ""
echo "--- 4. Looking for FundedNext in all files ---"
grep -rl "FundedNext" "$MT5/config/" 2>/dev/null
grep -rl "FundedNext" "$MT5/origin/" 2>/dev/null
grep -rl "FundedNext" "$MT5/bases/" 2>/dev/null

# 5. List bases directory (where server data is stored)
echo ""
echo "--- 5. Bases directory ---"
ls -la "$MT5/bases/" 2>&1
echo ""
if [ -d "$MT5/bases" ]; then
    for d in "$MT5/bases/"*/; do
        echo "Server: $(basename "$d")"
        ls -la "$d" 2>/dev/null | head -5
        echo ""
    done
fi

# 6. Check the common.ini for saved login info (non-portable)
echo ""
echo "--- 6. Main terminal config ---"
cat "$MT5/terminal64.ini" 2>/dev/null | head -50
echo ""
echo "--- AppData config ---"
cat "/root/.wine/drive_c/users/root/Application Data/MetaQuotes/Terminal/"*/common.ini 2>/dev/null | head -30

# 7. Check what servers MT5 knows about
echo ""
echo "--- 7. All server references ---"
find "$MT5" -maxdepth 3 -type d 2>/dev/null | grep -i "server\|funded\|bases" | head -20

# 8. Network connectivity to FundedNext
echo ""
echo "--- 8. Network test ---"
# Common FundedNext server IPs
nslookup mt5.fundednext.com 2>&1 || echo "DNS lookup failed"
ping -c1 -W3 mt5.fundednext.com 2>&1 || echo "Ping failed"

echo ""
echo "=== DONE ==="
