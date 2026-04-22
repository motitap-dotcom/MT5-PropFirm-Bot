#!/bin/bash
# v9 - copy futures_bot/ to /opt/ so concurrent branch resets can't wipe it
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

# Maintain a copy of the bot package at /opt/futures_bot_stable so it survives
# any `git reset --hard` on /root/MT5-PropFirm-Bot caused by concurrent Claude
# sessions pushing to other branches. The wrapper also self-heals the copy
# from whichever source is present, so we're never stuck when one side is
# wiped.
mkdir -p /opt/futures_bot_stable
if [ -f /root/MT5-PropFirm-Bot/futures_bot/bot.py ]; then
  rsync -a --delete /root/MT5-PropFirm-Bot/futures_bot/ /opt/futures_bot_stable/futures_bot/
  cp /root/MT5-PropFirm-Bot/requirements.txt /opt/futures_bot_stable/ 2>/dev/null || true
  [ -d /root/MT5-PropFirm-Bot/configs ] && rsync -a /root/MT5-PropFirm-Bot/configs/ /opt/futures_bot_stable/configs/
  echo "  Seeded /opt/futures_bot_stable from /root/MT5-PropFirm-Bot"
fi

install -m 755 /dev/stdin /usr/local/sbin/futures-bot-wrapper.sh << 'RUNEOF'
#!/bin/bash
# Wrapper invoked by systemd's ExecStart. Lives in /usr/local/sbin to survive
# wipes of /root/MT5-PropFirm-Bot. If the repo copy is present it takes
# precedence; otherwise we fall back to the stable copy at /opt.
set -e
STABLE=/opt/futures_bot_stable
REPO=/root/MT5-PropFirm-Bot

# Pick the side that still has bot.py
if [ -f "$REPO/futures_bot/bot.py" ]; then
  BOT_DIR="$REPO"
elif [ -f "$STABLE/futures_bot/bot.py" ]; then
  BOT_DIR="$STABLE"
  echo "[wrapper] repo copy missing, falling back to $STABLE"
else
  echo "[wrapper] FATAL: no bot.py found in $REPO or $STABLE" >&2
  exit 1
fi

cd "$BOT_DIR"
# Load .env: prefer repo copy (has fresh tokens written by workflows)
if [ -f "$REPO/.env" ]; then
  set -a; source "$REPO/.env"; set +a
elif [ -f "$STABLE/.env" ]; then
  set -a; source "$STABLE/.env"; set +a
fi
# Configs too — fall back to stable copy if the repo one was wiped
if [ ! -d "$BOT_DIR/configs" ] && [ -d "$STABLE/configs" ]; then
  cp -r "$STABLE/configs" "$BOT_DIR/configs"
fi
mkdir -p logs status
export PYTHONUNBUFFERED=1
echo "[wrapper] BOT_DIR=$BOT_DIR TRADOVATE_PASS_set=${TRADOVATE_PASS:+yes} bot.py=$(stat -c %s futures_bot/bot.py)B"
exec /usr/bin/python3 "$BOT_DIR/futures_bot/bot.py"
RUNEOF

cat > /etc/systemd/system/futures-bot.service << 'SVCEOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=/usr/local/sbin/futures-bot-wrapper.sh
Restart=on-failure
RestartSec=30
TimeoutStopSec=30
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
