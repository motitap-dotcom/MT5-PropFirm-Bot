#!/bin/bash
# Final status check + setup persistence
echo "=== FINAL STATUS $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "[1] AutoTrading state:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3

echo "[2] MT5 process:"
pgrep -a "start.exe\|terminal64" 2>/dev/null | head -3

echo "[3] Last 15 EA entries:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -15

echo "[4] Bot status:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null

echo "[5] Setup persistence..."
# Save the working keybd_event exe
cp /root/at_keybd.exe /root/enable_autotrading.exe 2>/dev/null || echo "  No at_keybd.exe found"

# Update reboot script to use Wine keybd_event
cat > /root/start_mt5_screen.sh << 'EOF'
#!/bin/bash
export DISPLAY=:99
export WINEPREFIX=/root/.wine
sleep 10
cd "/root/.wine/drive_c/Program Files/MetaTrader 5"
screen -dmS mt5 bash -c 'export DISPLAY=:99 && export WINEPREFIX=/root/.wine && wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server 2>&1'
# Wait for MT5 to fully load, then enable AutoTrading
sleep 25
wine "C:\\at_keybd.exe" 2>/dev/null
echo "$(date): MT5 started and AutoTrading enabled" >> /var/log/mt5_startup.log
EOF
chmod +x /root/start_mt5_screen.sh

# Update crontab
(crontab -l 2>/dev/null | grep -v "fix_autotrading\|start_mt5"; echo "@reboot /root/start_mt5_screen.sh") | crontab -
echo "  Crontab updated:"
crontab -l 2>/dev/null | grep mt5

echo "=== DONE $(date -u) ==="
