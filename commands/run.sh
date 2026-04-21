#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== Deep Check $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- Config symbols ---"
python3 -c "import json; c=json.load(open('configs/bot_config.json')); print('symbols:', c.get('symbols')); v=c.get('vwap',{}); print('rsi_oversold:', v.get('rsi_oversold')); print('rsi_overbought:', v.get('rsi_overbought')); print('min_atr:', v.get('min_atr')); print('max_atr:', v.get('max_atr'))"
echo ""
echo "--- Last 25 log lines ---"
tail -25 logs/bot.log 2>/dev/null
echo ""
echo "--- Status JSON ---"
cat status/status.json 2>/dev/null | python3 -m json.tool 2>/dev/null || cat status/status.json 2>/dev/null
