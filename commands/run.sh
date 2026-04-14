#!/bin/bash
# Trigger: deploy-v20-keepalive-fix
cd /root/MT5-PropFirm-Bot
echo "=== Deploy + Restart $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Branch: $(git rev-parse --abbrev-ref HEAD)"
echo "Commit: $(git log -1 --oneline)"
echo ""

echo "--- Verify keepalive fix is in code ---"
grep -c "Token keepalive failed" futures_bot/bot.py || echo "MISSING keepalive in bot.py"
grep -c "browser auth as last resort" futures_bot/core/tradovate_client.py || echo "MISSING Playwright fallback"
echo ""

echo "--- Service before restart ---"
echo "State: $(systemctl is-active futures-bot)"
echo "PID:   $(systemctl show futures-bot --property=MainPID --value)"
echo ""

# Restart in background so SSH session can still return output.
# Rule: systemctl restart inside run.sh normally breaks output return,
# so we detach it behind sleep + nohup + disown.
echo "--- Scheduling restart in 6s (detached) ---"
nohup bash -c 'sleep 6 && systemctl daemon-reload && systemctl restart futures-bot' \
    > /tmp/restart_$(date +%s).log 2>&1 < /dev/null &
disown
echo "Restart job pid: $!"
echo ""

echo "=== END (VPS output will commit before restart fires) ==="
