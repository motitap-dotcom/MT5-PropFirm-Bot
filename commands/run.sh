#!/bin/bash
# Trigger: fix-service-v1 — fix systemd + restart bot
cd /root/MT5-PropFirm-Bot

echo "=== Fixing Service + Restarting ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# Create directories
mkdir -p status logs configs

# Remove drop-in override
rm -rf /etc/systemd/system/futures-bot.service.d

# Write correct service file
cat > /etc/systemd/system/futures-bot.service << 'EOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=/bin/bash /root/MT5-PropFirm-Bot/scripts/start_bot.sh
Restart=always
RestartSec=30
MemoryMax=2G
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
EOF

chmod +x scripts/start_bot.sh

# Reload and restart
systemctl daemon-reload
systemctl restart futures-bot
sleep 10

echo ""
echo "=== New Service File ==="
cat /etc/systemd/system/futures-bot.service
echo ""
echo "Drop-ins:"
ls /etc/systemd/system/futures-bot.service.d/ 2>/dev/null || echo "None (good)"
echo ""

echo "=== Service Status ==="
systemctl status futures-bot --no-pager | head -15
echo ""

echo "=== Last 20 Journal Lines ==="
journalctl -u futures-bot --no-pager -n 20
echo ""

echo "=== Status File ==="
cat status/status.json 2>/dev/null || echo "Not yet written"
echo ""

echo "=== Token ==="
python3 -c "
import json, time
d = json.loads(open('configs/.tradovate_token.json').read())
exp = d.get('expiry', 0)
remaining = exp - time.time()
print(f'Remaining: {remaining/60:.0f} minutes')
print(f'Saved: {d.get(\"saved_at\", \"unknown\")}')
" 2>/dev/null || echo "No token"

echo ""
echo "=== DONE ==="
