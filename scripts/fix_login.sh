#!/bin/bash
# Fix login: try different password escaping methods
echo "=== FIX LOGIN $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

echo "--- 1. Kill MT5 ---"
pkill -f terminal64.exe 2>/dev/null; sleep 3
wineserver -k 2>/dev/null; sleep 3

echo ""
echo "--- 2. Ensure correct servers.dat ---"
# Make sure we have the working version
if [ $(stat -c%s "$MT5/config/servers.dat" 2>/dev/null || echo 0) -lt 60000 ]; then
    cp "$MT5/Config/servers.dat" "$MT5/config/servers.dat" 2>/dev/null
    echo "Restored servers.dat from backup"
fi
echo "servers.dat: $(stat -c%s "$MT5/config/servers.dat" 2>/dev/null) bytes"

echo ""
echo "--- 3. Try approach: config file with password ---"
# Create a proper INI startup config
PASS='gazDE62##'
cat > "$MT5/config/startup.ini" << SEOF
[Common]
Login=11797849
Password=${PASS}
Server=FundedNext-Server
ProxyEnable=0
CertInstall=0
NewsEnable=0
EnableOpenCL=7
Services=4294967295
Source=download.mql5.com
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
WebRequest=1
[Charts]
ProfileLast=Default
MaxBars=100000
TradeHistory=1
TradeLevels=1
PreloadCharts=1
SEOF

echo "Created startup.ini with password"

echo ""
echo "--- 4. Start MT5 with config file ---"
cd "$MT5"
nohup wine terminal64.exe "/config:C:\Program Files\MetaTrader 5\config\startup.ini" </dev/null >/dev/null 2>&1 &
disown -a
echo "MT5 started with config file, waiting 90s..."
sleep 90

echo ""
echo "--- 5. Check connection ---"
TLOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
AUTH=""
[ -n "$TLOG" ] && AUTH=$(cat "$TLOG" | tr -d '\0' | grep -i "Network" | tail -5)
echo "Network messages:"
echo "$AUTH"

CONNECTED=0
echo "$AUTH" | grep -q "authorized on" && CONNECTED=1

if [ $CONNECTED -eq 1 ]; then
    echo "*** CONNECTED! ***"
else
    echo "Config file approach failed, trying direct with single quotes..."

    pkill -f terminal64.exe 2>/dev/null; sleep 3
    wineserver -k 2>/dev/null; sleep 3

    echo ""
    echo "--- 6. Try with password in single quotes ---"
    cd "$MT5"
    nohup wine terminal64.exe /login:11797849 /password:'gazDE62##' /server:FundedNext-Server </dev/null >/dev/null 2>&1 &
    disown -a
    echo "Waiting 90s..."
    sleep 90

    TLOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
    AUTH=""
    [ -n "$TLOG" ] && AUTH=$(cat "$TLOG" | tr -d '\0' | grep -i "Network" | tail -5)
    echo "Network messages:"
    echo "$AUTH"

    echo "$AUTH" | grep -q "authorized on" && CONNECTED=1

    if [ $CONNECTED -eq 1 ]; then
        echo "*** CONNECTED with single quotes! ***"
    else
        echo "Also failed. Trying FundedNext-Server 2..."

        pkill -f terminal64.exe 2>/dev/null; sleep 3
        wineserver -k 2>/dev/null; sleep 3

        echo ""
        echo "--- 7. Try FundedNext-Server 2 ---"
        cd "$MT5"
        # Update common.ini to use Server 2
        sed -i 's/Server=FundedNext-Server$/Server=FundedNext-Server 2/' "$MT5/config/common.ini"
        nohup wine terminal64.exe /login:11797849 /password:'gazDE62##' "/server:FundedNext-Server 2" </dev/null >/dev/null 2>&1 &
        disown -a
        echo "Trying Server 2, waiting 90s..."
        sleep 90

        TLOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
        AUTH=""
        [ -n "$TLOG" ] && AUTH=$(cat "$TLOG" | tr -d '\0' | grep -i "Network" | tail -5)
        echo "Network messages:"
        echo "$AUTH"

        echo "$AUTH" | grep -q "authorized on" && CONNECTED=1

        if [ $CONNECTED -eq 1 ]; then
            echo "*** CONNECTED on Server 2! ***"
        else
            echo "Server 2 also failed."
            # Restore original server
            sed -i 's/Server=FundedNext-Server 2/Server=FundedNext-Server/' "$MT5/config/common.ini"
        fi
    fi
fi

echo ""
echo "--- 8. Final status ---"
echo "MT5: $(pgrep -f terminal64.exe > /dev/null 2>&1 && echo RUNNING || echo NOT_RUNNING)"
echo ""
echo "Terminal log (last 15):"
TLOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
[ -n "$TLOG" ] && cat "$TLOG" | tr -d '\0' | tail -15
echo ""
echo "Connections:"
ss -tn state established | grep -v ":22 \|:5900 \|:53 " | head -10
echo ""
echo "EA log:"
TODAY=$(date '+%Y%m%d')
EALOG="$MT5/MQL5/Logs/${TODAY}.log"
[ -f "$EALOG" ] && cat "$EALOG" | tr -d '\0' | tail -15 || echo "No EA log"

# Install watchdog with correct login
echo ""
echo "--- 9. Update watchdog ---"
mkdir -p /root/PropFirmBot/scripts /root/PropFirmBot/logs /root/PropFirmBot/state
if [ -f /tmp/watchdog.sh ]; then
    cp /tmp/watchdog.sh /root/PropFirmBot/scripts/watchdog.sh
    chmod +x /root/PropFirmBot/scripts/watchdog.sh
fi

CRON_TMP=$(mktemp)
crontab -l 2>/dev/null > "$CRON_TMP" || true
sed -i '/PropFirmBot/d' "$CRON_TMP"
echo "*/2 * * * * /root/PropFirmBot/scripts/watchdog.sh  # PropFirmBot watchdog" >> "$CRON_TMP"
crontab "$CRON_TMP" && rm "$CRON_TMP"
echo "Watchdog: $(crontab -l 2>/dev/null | grep -q PropFirmBot && echo ACTIVE || echo NOT_SET)"

echo ""
echo "=== DONE ==="
