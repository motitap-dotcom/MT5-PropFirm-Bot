#!/bin/bash
# Trigger: fix-service-v2 — inline ExecStart, no script file needed
cd /root/MT5-PropFirm-Bot

echo "=== Fix Service v2 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# Create directories
mkdir -p status logs configs

# Debug: what's in scripts/?
echo "scripts/ contents:"
ls -la scripts/ 2>/dev/null || echo "No scripts dir"
echo ""

# Remove drop-in override
rm -rf /etc/systemd/system/futures-bot.service.d

# Write service with inline command (no external script needed)
cat > /etc/systemd/system/futures-bot.service << 'EOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=/bin/bash -c 'cd /root/MT5-PropFirm-Bot && exec venv/bin/python -m futures_bot.bot'
Restart=always
RestartSec=30
MemoryMax=2G
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl restart futures-bot
sleep 10

echo "=== Service Status ==="
systemctl status futures-bot --no-pager | head -20
echo ""

echo "=== Last 15 Journal Lines ==="
journalctl -u futures-bot --no-pager -n 15
echo ""

echo "=== Token ==="
python3 -c "
import json, time
d = json.loads(open('configs/.tradovate_token.json').read())
remaining = d.get('expiry', 0) - time.time()
print(f'Remaining: {remaining/60:.0f} min | Saved: {d.get(\"saved_at\", \"?\")}')" 2>/dev/null || echo "No token"
echo ""
echo "=== DONE ==="
