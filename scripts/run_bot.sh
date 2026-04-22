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
# Sanity log so we can see in journalctl what we got
echo "[run_bot.sh] cwd=$(pwd)"
echo "[run_bot.sh] TRADOVATE_USER=${TRADOVATE_USER:0:3}*** TRADOVATE_PASS set=${TRADOVATE_PASS:+yes}"
echo "[run_bot.sh] PYTHONPATH=$PYTHONPATH"
echo "[run_bot.sh] futures_bot present: $(ls -d futures_bot/ 2>/dev/null || echo MISSING)"
exec /usr/bin/python3 -m futures_bot.bot
