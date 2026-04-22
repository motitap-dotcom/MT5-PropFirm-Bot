#!/bin/bash
echo "=== Fix & Restart ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot

# NOTE: vps-fix.yml already ran `git reset --hard origin/<ref_name>` before
# invoking this script, so we already have the latest code from the branch
# that triggered the workflow. Don't re-pull from main (auto-merge is broken).
echo "Code: $(git log -1 --oneline)"
echo "Branch HEAD tree has:"
grep -c "Playwright browser auth as fallback" futures_bot/core/tradovate_client.py \
  && echo "  ✓ new Playwright fallback is present" \
  || echo "  ✗ new Playwright fallback NOT in tree"

# Delete stale token so bot does a fresh auth (Playwright will kick in)
if [ -f configs/.tradovate_token.json ]; then
  echo "Deleting stale token to force fresh auth..."
  rm -f configs/.tradovate_token.json
fi
rm -f /tmp/.tradovate_token_backup.json

# Ensure dirs
mkdir -p status logs

# Install deps (includes playwright) and chromium if missing
echo "Installing Python deps..."
pip3 install -r requirements.txt -q 2>&1 | tail -3 || true
if ! python3 -c "import playwright" 2>/dev/null; then
  echo "Installing playwright package..."
  pip3 install playwright -q 2>&1 | tail -3
fi
if [ ! -d /root/.cache/ms-playwright ] || [ -z "$(ls -A /root/.cache/ms-playwright 2>/dev/null)" ]; then
  echo "Installing chromium..."
  python3 -m playwright install chromium 2>&1 | tail -5
fi

# Service with PYTHONPATH
cat > /etc/systemd/system/futures-bot.service << 'SVCEOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=/usr/bin/python3 -m futures_bot.bot
Restart=on-failure
RestartSec=60
Environment=PYTHONUNBUFFERED=1
Environment=PYTHONPATH=/root/MT5-PropFirm-Bot
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null
systemctl restart futures-bot
echo "Waiting 20s for bot to boot + authenticate..."
sleep 20

echo ""
echo "=== Post-restart status ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "=== Last 40 log lines ==="
tail -40 logs/bot.log 2>/dev/null || echo "no log yet"
