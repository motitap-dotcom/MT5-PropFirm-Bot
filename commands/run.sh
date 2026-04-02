#!/bin/bash
# Trigger: v120 - Full fix (no git reset, safe for bot)
cd /root/MT5-PropFirm-Bot
exec > commands/output.txt 2>&1

echo "=== FULL FIX v118 ==="
date -u
echo ""

# 1. Create permanent wrapper (survives git reset)
cat > /usr/local/bin/start-futures-bot.sh << 'WRAPPER'
#!/bin/bash
cd /root/MT5-PropFirm-Bot
export PYTHONPATH=/root/MT5-PropFirm-Bot
exec /usr/bin/python3 -m futures_bot.bot
WRAPPER
chmod +x /usr/local/bin/start-futures-bot.sh
echo "Wrapper: /usr/local/bin/start-futures-bot.sh created"

# 2. Fix service file
cat > /etc/systemd/system/futures-bot.service << 'EOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/start-futures-bot.sh
Restart=on-failure
RestartSec=60
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
EOF
echo "Service file updated"

# 3. Ensure dirs exist
mkdir -p status logs configs

# 4. Verify code exists
echo ""
echo "=== Verify ==="
ls futures_bot/__init__.py futures_bot/bot.py futures_bot/core/tradovate_client.py 2>&1
PYTHONPATH=/root/MT5-PropFirm-Bot /usr/bin/python3 -c "from futures_bot.bot import main; print('Import: OK')" 2>&1
echo ""

# 5. Restart bot
systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null
systemctl stop futures-bot 2>/dev/null
sleep 2
systemctl start futures-bot
echo "Bot restarted"

# 6. Wait and check
sleep 20
echo ""
echo "=== Result ==="
echo "Service: $(systemctl is-active futures-bot)"
echo ""
echo "=== Bot Log ==="
tail -25 logs/bot.log 2>/dev/null || echo "No log"
echo ""
echo "=== Journal ==="
journalctl -u futures-bot --no-pager -n 10 2>&1
echo ""
echo "=== Token ==="
cat configs/.tradovate_token.json 2>/dev/null | head -3 || echo "No token"
echo ""
echo "=== END ==="
