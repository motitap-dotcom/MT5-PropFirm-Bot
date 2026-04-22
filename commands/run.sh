#!/bin/bash
# Trigger: v149 - deep diagnostic why bot not trading
cd /root/MT5-PropFirm-Bot
echo "=== v149 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- Service ---"
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "Code: $(git log -1 --oneline)"
echo ""
echo "--- Status JSON ---"
if [ -f status/status.json ]; then
  cat status/status.json
else
  echo "status.json MISSING"
fi
echo ""
echo "--- Positions on account ---"
if [ -f configs/.tradovate_token.json ]; then
  TOKEN=$(python3 -c "import json;print(json.load(open('configs/.tradovate_token.json'))['accessToken'])" 2>/dev/null)
  if [ -n "$TOKEN" ]; then
    curl -s -H "Authorization: Bearer $TOKEN" https://live.tradovateapi.com/v1/position/list | head -c 500
    echo ""
    echo "--- Open orders ---"
    curl -s -H "Authorization: Bearer $TOKEN" https://live.tradovateapi.com/v1/order/list | head -c 500
  else
    echo "Could not parse token"
  fi
else
  echo "No token file"
fi
echo ""
echo ""
echo "--- Last 80 log lines ---"
tail -80 logs/bot.log 2>/dev/null
echo ""
echo "--- Trade-related log lines (last 200 matching) ---"
grep -iE "signal|entry|strategy|vwap|orb|no trade|skip|blocked|market data|session|flatten|reject" logs/bot.log 2>/dev/null | tail -40
echo ""
echo "--- Config ---"
[ -f configs/bot_config.json ] && head -40 configs/bot_config.json || echo "bot_config.json MISSING"
echo ""
echo "--- Time info ---"
echo "UTC: $(date -u)"
echo "NY:  $(TZ=America/New_York date)"
