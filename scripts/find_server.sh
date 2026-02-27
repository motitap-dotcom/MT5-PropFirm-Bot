#!/bin/bash
# Find FundedNext server IP from old logs and configs
echo "=== FIND FUNDEDNEXT SERVER $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo ""
echo "--- 1. Search old terminal logs for server IP ---"
for logfile in "$MT5/logs/"*.log; do
    [ -f "$logfile" ] || continue
    echo "  Checking: $(basename "$logfile")"
    # Look for connection/authorization messages
    cat "$logfile" 2>/dev/null | tr -d '\0' | grep -iE "connect|authoriz|server|login|account" | head -10
done

echo ""
echo "--- 2. Search old EA logs for server info ---"
for logfile in "$MT5/MQL5/Logs/"*.log; do
    [ -f "$logfile" ] || continue
    echo "  Checking: $(basename "$logfile")"
    cat "$logfile" 2>/dev/null | tr -d '\0' | grep -iE "connect|server|account|authoriz|broker|balance" | head -10
done

echo ""
echo "--- 3. All files in config/servers ---"
find "$MT5/config" -type f 2>/dev/null | while read f; do
    echo "  $f ($(stat -c%s "$f" 2>/dev/null) bytes)"
done
find "$MT5/config" -type d 2>/dev/null | while read d; do
    echo "  DIR: $d"
done

echo ""
echo "--- 4. Search for .srv files anywhere in MT5 ---"
find "$MT5" -name "*.srv" -o -name "*.dat" -o -name "server*" 2>/dev/null | head -20

echo ""
echo "--- 5. Search for FundedNext in ALL files ---"
grep -rl "FundedNext" "$MT5/config/" 2>/dev/null | head -10
grep -rl "FundedNext" "$MT5/" --include="*.ini" --include="*.cfg" --include="*.srv" --include="*.dat" 2>/dev/null | head -10

echo ""
echo "--- 6. Check if server info exists in profile ---"
find "$MT5/Profiles" -type f 2>/dev/null | head -20

echo ""
echo "--- 7. Full hexdump of common.ini for hidden data ---"
xxd "$MT5/config/common.ini" 2>/dev/null | grep -i "fund\|serv\|185\|188\|next" | head -20

echo ""
echo "--- 8. Check Wine registry for server info ---"
grep -i "fundednext\|FundedNext\|Server" /root/.wine/user.reg 2>/dev/null | head -20

echo ""
echo "--- 9. Download FundedNext MT5 setup to extract server config ---"
echo "Trying known download URL patterns..."
# Try common MQL5 CDN patterns for FundedNext
for url in \
    "https://download.mql5.com/cdn/web/fundednext.ltd/mt5/fundednext5setup.exe" \
    "https://download.mql5.com/cdn/web/funded.next.ltd/mt5/fundednext5setup.exe" \
    "https://download.mql5.com/cdn/web/fundednext.com/mt5/fundednext5setup.exe" \
    "https://download.mql5.com/cdn/web/fundednext/mt5/fundednext5setup.exe" \
    "https://download.mql5.com/cdn/web/19906/mt5/fundednext5setup.exe" \
    "https://download.mql5.com/cdn/web/fn.markets.ltd/mt5/fundednext5setup.exe"; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null)
    echo "  $url -> HTTP $STATUS"
    if [ "$STATUS" = "200" ]; then
        echo "  FOUND! Downloading..."
        curl -L -o /tmp/fn_mt5_setup.exe "$url" 2>/dev/null
        echo "  Downloaded: $(stat -c%s /tmp/fn_mt5_setup.exe 2>/dev/null) bytes"
        # Try to extract server info from the exe
        strings /tmp/fn_mt5_setup.exe 2>/dev/null | grep -iE "fundednext|server|185\." | sort -u | head -20
        break
    fi
done

echo ""
echo "--- 10. Try to resolve FundedNext via MQL5 trade API ---"
# MT5 web terminal may reveal server addresses
curl -s "https://trade.metatrader5.com/trade?servers=FundedNext-Server" 2>/dev/null | head -50

echo ""
echo "--- 11. Check /root for any old MT5 backups ---"
find /root -name "*.srv" -o -name "server*.dat" 2>/dev/null | head -10
find /root -path "*/FundedNext*" -type f 2>/dev/null | head -10

echo ""
echo "--- 12. Full search for IP-like patterns in config files ---"
find "$MT5/config" -type f -exec strings {} \; 2>/dev/null | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | sort -u

echo ""
echo "--- 13. Check if maybe it needs to download server list ---"
# Check MQL5 trade server directory
curl -s "https://trade.mql5.com/trade?servers=FundedNext-Server&version=5640" 2>/dev/null | strings | head -30
curl -s "https://mt5web.fundednext.com" -I 2>/dev/null | head -10

echo ""
echo "=== END SEARCH ==="
