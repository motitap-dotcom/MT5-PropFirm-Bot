#!/bin/bash
# Trigger: v152
cd /root/MT5-PropFirm-Bot
echo "=== Post-Fix Verification $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "=== Service ==="
echo "Status: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Code: $(git log -1 --oneline)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "=== Last 30 log lines ==="
tail -30 logs/bot.log 2>/dev/null || echo "No log"
echo ""
echo "=== Trading days counter (should NOT be 0 anymore) ==="
grep "Trading days" logs/bot.log 2>/dev/null | tail -5
echo ""
echo "=== EOD Flatten (should be max 1 per day, not spam) ==="
grep "FLATTENING ALL" logs/bot.log 2>/dev/null | tail -10
echo ""
echo "=== Status JSON (should have real data) ==="
cat status/status.json 2>/dev/null || echo "No status.json"
echo ""
echo "=== Recent trades opened ==="
grep "record_trade_opened\|TRADE:" logs/bot.log 2>/dev/null | tail -10
echo ""
echo "=== Balance updates ==="
grep "update_balance\|day_start_balance\|daily_pnl" logs/bot.log 2>/dev/null | tail -5
echo ""
echo "=== End ==="
