#!/bin/bash
# Trigger: v99 - Quick diag
cd /root/MT5-PropFirm-Bot
echo "=== Quick Diag v99 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "Branch: $(git branch --show-current)"
echo "Commit: $(git log -1 --oneline)"
echo ""
echo "Python3: $(which python3) $(python3 --version 2>&1)"
echo "pip3: $(which pip3)"
echo ""
echo "=== Module check ==="
python3 -c "import aiohttp; print('aiohttp OK')" 2>&1
python3 -c "import websockets; print('websockets OK')" 2>&1
python3 -c "import futures_bot; print('futures_bot OK')" 2>&1
python3 -c "import futures_bot.bot; print('futures_bot.bot OK')" 2>&1
echo ""
echo "=== .env ==="
[ -f .env ] && echo "exists ($(wc -l < .env) lines)" || echo "MISSING"
echo ""
echo "=== Token ==="
[ -f configs/.tradovate_token.json ] && echo "token file exists" || echo "token file MISSING"
echo ""
echo "=== Service file ==="
cat /etc/systemd/system/futures-bot.service 2>/dev/null | grep ExecStart
echo ""
echo "=== Service status ==="
systemctl is-active futures-bot 2>&1
echo ""
echo "=== Last 10 journal lines ==="
journalctl -u futures-bot --no-pager -n 10 2>&1
