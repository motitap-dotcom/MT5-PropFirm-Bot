#!/bin/bash
echo "=== VPS Full Scan - What's Running ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "--- All Running Services ---"
systemctl list-units --type=service --state=running --no-pager 2>/dev/null | grep -v systemd
echo ""

echo "--- All Python Processes ---"
ps aux | grep -i python | grep -v grep
echo ""

echo "--- All Node/JS Processes ---"
ps aux | grep -i node | grep -v grep
echo ""

echo "--- Wine/MT5 Processes ---"
ps aux | grep -i wine | grep -v grep
ps aux | grep -i mt5 | grep -v grep
ps aux | grep -i metatrader | grep -v grep
echo ""

echo "--- Tradovate Related ---"
find /root -maxdepth 4 -name "*tradovate*" -o -name "*tradeday*" -o -name "*futures*" 2>/dev/null | head -30
echo ""

echo "--- All Repos/Projects in /root ---"
ls -la /root/ | grep -E "^d"
echo ""

echo "--- Check for other bots ---"
find /root -maxdepth 3 -name "bot.py" -o -name "*.py" -name "*bot*" -o -name "*.py" -name "*trade*" 2>/dev/null | head -20
echo ""

echo "--- Systemd Custom Services ---"
ls -la /etc/systemd/system/*.service 2>/dev/null | grep -v systemd
echo ""

echo "--- .env files ---"
find /root -maxdepth 3 -name ".env" 2>/dev/null
echo ""

echo "--- Crontab ---"
crontab -l 2>/dev/null || echo "No crontab"
echo ""

echo "=== Scan Complete ==="
