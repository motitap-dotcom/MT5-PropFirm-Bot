#!/bin/bash
# Force reload EA with new params by killing MT5 and restarting fresh
echo "=== FORCE RELOAD EA $(date) ==="

export DISPLAY=:99
export WINEPREFIX=/root/.wine

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"

# 1. Check current chart settings for XAUUSD param
echo "=== CURRENT EA SETTINGS IN CHART ==="
CHART_DIR="$MT5/MQL5/Profiles/Charts/Default"
for chr in "$CHART_DIR"/chart*.chr; do
    if grep -l "PropFirmBot" "$chr" 2>/dev/null; then
        echo "Found EA in: $(basename $chr)"
        # Show the XAUUSD param
        grep -A1 -i "xauusd\|TradeXAUUSD\|InpTradeXAUUSD" "$chr" 2>/dev/null
        echo "---"
        # Show all expert params
        grep -A200 "expert_" "$chr" 2>/dev/null | head -60
    fi
done

# 2. Try to find and fix the chart file
echo ""
echo "=== FIXING CHART PARAMS ==="
for chr in "$CHART_DIR"/chart*.chr; do
    if grep -q "PropFirmBot" "$chr" 2>/dev/null; then
        echo "Patching: $(basename $chr)"
        # Replace InpTradeXAUUSD=false with true
        sed -i 's/InpTradeXAUUSD=false/InpTradeXAUUSD=true/g' "$chr" 2>/dev/null
        sed -i 's/InpTradeXAUUSD=0/InpTradeXAUUSD=1/g' "$chr" 2>/dev/null
        echo "After patch:"
        grep -i "xauusd\|TradeXAUUSD" "$chr" 2>/dev/null
    fi
done

# 3. Kill and restart MT5
echo ""
echo "=== RESTARTING MT5 ==="
pkill -f terminal64 2>/dev/null
sleep 5

cd "$MT5"
nohup wine64 terminal64.exe /portable > /dev/null 2>&1 &
sleep 15

# 4. Check log
echo ""
echo "=== EA LOG ==="
LATEST=$(ls -t "$MT5/MQL5/Logs"/*.log 2>/dev/null | head -1)
tail -20 "$LATEST" 2>/dev/null

echo ""
echo "=== DONE $(date) ==="
