#!/bin/bash
echo "=== Fix & Restart ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot

# Preserve token
cp configs/.tradovate_token.json /tmp/.tradovate_token_backup.json 2>/dev/null || true

# Pull latest — prefer main, fall back to current branch
if git fetch origin main 2>/dev/null; then
    git reset --hard origin/main
    echo "Code: $(git log -1 --oneline) [from main]"
else
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [ -n "$CURRENT_BRANCH" ]; then
        git fetch origin "$CURRENT_BRANCH" 2>/dev/null || true
        git reset --hard "origin/$CURRENT_BRANCH" 2>/dev/null || true
        echo "Code: $(git log -1 --oneline) [from $CURRENT_BRANCH]"
    fi
fi

# Restore token
cp /tmp/.tradovate_token_backup.json configs/.tradovate_token.json 2>/dev/null || true

# Ensure dirs
mkdir -p status logs scripts

# Always (re)create start_bot.sh — self-contained, no dependency on git having it
cat > /root/MT5-PropFirm-Bot/scripts/start_bot.sh << 'WRAPEOF'
#!/bin/bash
export PYTHONPATH=/root/MT5-PropFirm-Bot
cd /root/MT5-PropFirm-Bot
exec /usr/bin/python3 -m futures_bot.bot
WRAPEOF
chmod +x /root/MT5-PropFirm-Bot/scripts/start_bot.sh
echo "start_bot.sh written."

# Write service file
cat > /etc/systemd/system/futures-bot.service << 'SVCEOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=/bin/bash /root/MT5-PropFirm-Bot/scripts/start_bot.sh
Restart=on-failure
RestartSec=30
Environment=PYTHONUNBUFFERED=1
Environment=PYTHONPATH=/root/MT5-PropFirm-Bot
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable futures-bot
systemctl reset-failed futures-bot 2>/dev/null
systemctl restart futures-bot
sleep 5
echo "Status: $(systemctl is-active futures-bot)"
echo "Journal:"
journalctl -u futures-bot --no-pager -n 8
