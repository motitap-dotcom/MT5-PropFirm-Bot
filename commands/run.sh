#!/bin/bash
# Trigger: v160 - full health check
cd /root/MT5-PropFirm-Bot
echo "=== Full Health Check v160 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "=== 1. SERVICE ==="
echo "Status: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "Restarts: $(systemctl show futures-bot --property=NRestarts --value)"
echo ""
echo "=== 2. CRITICAL FILES ==="
echo "status dir: $(ls -d status/ 2>&1)"
echo "status.json writable: $(touch status/test_write 2>&1 && echo YES && rm status/test_write || echo NO)"
echo "status.json: $(ls -la status/status.json 2>&1)"
echo "restricted_events: $(ls -la configs/restricted_events.json 2>&1)"
echo "bot_config: $(ls -la configs/bot_config.json 2>&1)"
echo ".env: $(ls -la .env 2>&1)"
echo "token: $(ls -la configs/.tradovate_token.json 2>&1)"
echo ""
echo "=== 3. TRADING ACTIVITY ==="
echo "--- Signals, trades, positions from log ---"
grep -i -E "signal|order.*placed|fill|position|entry|exit|buy|sell|blocked|ORB|VWAP.*signal|trade" logs/bot.log 2>/dev/null | grep "2026-04-08" | tail -30
echo ""
echo "=== 4. STATUS JSON (live) ==="
cat status/status.json 2>/dev/null || echo "CANNOT READ status.json"
echo ""
echo "=== 5. ERRORS in last hour ==="
grep -i "error\|warning\|fail" logs/bot.log 2>/dev/null | grep "2026-04-08" | tail -15
echo ""
echo "=== 6. FULL LOG (last 40 lines) ==="
tail -40 logs/bot.log 2>/dev/null
