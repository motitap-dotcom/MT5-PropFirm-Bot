#!/bin/bash
# Trigger: v124 - Direct python path (no -m flag)
cd /root/MT5-PropFirm-Bot

echo "=== DEBUG + FIX v124 ==="
date -u

# Debug: what's actually on the VPS
echo "=== Files ==="
ls -la futures_bot/__init__.py futures_bot/bot.py 2>&1
echo ""

echo "=== Python test ==="
export PYTHONPATH=/root/MT5-PropFirm-Bot
/usr/bin/python3 -c "import sys; sys.path.insert(0,'/root/MT5-PropFirm-Bot'); import futures_bot; print('pkg OK')" 2>&1
/usr/bin/python3 -c "import sys; sys.path.insert(0,'/root/MT5-PropFirm-Bot'); from futures_bot import bot; print('bot OK')" 2>&1
echo ""

# New wrapper: use python3 with sys.path instead of -m
echo '#!/bin/bash' > /usr/local/bin/start-futures-bot.sh
echo 'cd /root/MT5-PropFirm-Bot' >> /usr/local/bin/start-futures-bot.sh
echo 'exec /usr/bin/python3 -c "import sys; sys.path.insert(0, '"'"'/root/MT5-PropFirm-Bot'"'"'); from futures_bot.bot import main; import asyncio; asyncio.run(main())"' >> /usr/local/bin/start-futures-bot.sh
chmod +x /usr/local/bin/start-futures-bot.sh
echo "Wrapper: $(cat /usr/local/bin/start-futures-bot.sh)"
echo ""

systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null
systemctl restart futures-bot

sleep 15
echo "Service: $(systemctl is-active futures-bot)"
tail -15 logs/bot.log 2>/dev/null
journalctl -u futures-bot --no-pager -n 5 2>&1
echo "=== END ==="
