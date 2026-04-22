#!/bin/bash
# v6 - write run_bot.sh inline so it can't go missing
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

# Back to the external wrapper (run_bot.sh). This was confirmed working at
# 15:14 UTC — the inline bash -c version regressed to "No module named
# futures_bot.bot" for reasons I still can't explain.
# v6: write run_bot.sh OURSELVES so it can't go missing. The systemd service
# keeps ending up in a restart loop with status=127 "No such file or
# directory" whenever the file isn't on disk after a reset — creating it here
# guarantees it exists the moment systemctl start runs.
mkdir -p /root/MT5-PropFirm-Bot/scripts
cat > /root/MT5-PropFirm-Bot/scripts/run_bot.sh << 'RUNEOF'
#!/bin/bash
# Wrapper invoked by systemd's ExecStart.
# Loads the .env file ourselves (so we don't rely on systemd's EnvironmentFile
# parser) and sets PYTHONPATH + cwd explicitly before exec'ing python.
set -e
cd /root/MT5-PropFirm-Bot
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi
export PYTHONPATH=/root/MT5-PropFirm-Bot
export PYTHONUNBUFFERED=1
echo "[run_bot.sh] cwd=$(pwd)"
echo "[run_bot.sh] TRADOVATE_USER=${TRADOVATE_USER:0:3}*** TRADOVATE_PASS set=${TRADOVATE_PASS:+yes}"
echo "[run_bot.sh] PYTHONPATH=$PYTHONPATH"
echo "[run_bot.sh] futures_bot present: $(ls -d futures_bot/ 2>/dev/null || echo MISSING)"
exec /usr/bin/python3 -m futures_bot.bot
RUNEOF
chmod +x /root/MT5-PropFirm-Bot/scripts/run_bot.sh

cat > /etc/systemd/system/futures-bot.service << 'SVCEOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=/bin/bash /root/MT5-PropFirm-Bot/scripts/run_bot.sh
Restart=on-failure
RestartSec=30
TimeoutStopSec=20
KillSignal=SIGINT
KillMode=mixed
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF

# Stop hard + clear failure counter so auto-restart loop doesn't keep firing
systemctl stop futures-bot 2>/dev/null
pkill -f "python3 -m futures_bot.bot" 2>/dev/null || true
sleep 2
systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null
systemctl start futures-bot
echo "Waiting 20s for bot to boot + authenticate..."
sleep 20

echo ""
echo "=== Post-restart status ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "=== Last 40 log lines ==="
tail -40 logs/bot.log 2>/dev/null || echo "no log yet"
