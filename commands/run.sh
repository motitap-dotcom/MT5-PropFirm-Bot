#!/bin/bash
# Trigger: v151
cd /root/MT5-PropFirm-Bot
echo "=== Full Trade Analysis $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "=== Service Status ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "Code: $(git log -1 --oneline)"
echo ""
echo "=== ALL Signals Generated (full history) ==="
grep -iE "SIGNAL" logs/bot.log 2>/dev/null || echo "None"
echo ""
echo "=== ALL Trade Executions ==="
grep -iE "TRADE:|Market order placed" logs/bot.log 2>/dev/null || echo "None"
echo ""
echo "=== ALL Blocked Trades ==="
grep -iE "BLOCKED|blocked by" logs/bot.log 2>/dev/null || echo "None"
echo ""
echo "=== Stop/Limit Orders ==="
grep -iE "Stop order|Limit order|Cancel" logs/bot.log 2>/dev/null || echo "None"
echo ""
echo "=== Position Closes / Fills ==="
grep -iE "fill|closed|exit|flatten|liquidat|P&L|pnl|profit|loss" logs/bot.log 2>/dev/null || echo "None"
echo ""
echo "=== Guardian State Changes ==="
grep -iE "guardian|state|ACTIVE|CLOSING|LOCKED|drawdown|daily|Trading days|Total PnL" logs/bot.log 2>/dev/null || echo "None"
echo ""
echo "=== Risk Manager Decisions ==="
grep -iE "risk|position size|max position|contracts" logs/bot.log 2>/dev/null | tail -20 || echo "None"
echo ""
echo "=== Account/Balance ==="
grep -iE "balance|equity|account|connected" logs/bot.log 2>/dev/null || echo "None"
echo ""
echo "=== Errors ==="
grep -iE "ERROR|WARNING|exception|fail" logs/bot.log 2>/dev/null | tail -20 || echo "None"
echo ""
echo "=== Status JSON ==="
cat status/status.json 2>/dev/null || echo "No status.json"
echo ""
echo "=== Bot Config (trade limits) ==="
python3 -c "
import json
with open('configs/bot_config.json') as f:
    cfg = json.load(f)
print(json.dumps(cfg.get('risk_management', {}), indent=2))
print('---')
print(json.dumps(cfg.get('guardian', {}), indent=2))
print('---')
print('Symbols:', json.dumps(cfg.get('symbols', [])))
print('Timeframe:', cfg.get('timeframe', 'N/A'))
" 2>/dev/null || echo "Config not found"
echo ""
echo "=== End Analysis ==="
