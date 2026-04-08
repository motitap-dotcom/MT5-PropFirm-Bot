#!/bin/bash
# Trigger: v155 - deep diagnostic for PYTHONPATH issue
cd /root/MT5-PropFirm-Bot
echo "=== Deep Diagnostic v155 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- Service file (raw) ---"
cat /etc/systemd/system/futures-bot.service
echo ""
echo "--- systemd show Environment ---"
systemctl show futures-bot --property=Environment
echo ""
echo "--- .env file content (redacted passwords) ---"
cat .env 2>/dev/null | sed 's/\(PASS\|TOKEN\|SECRET\)=.*/\1=***REDACTED***/'
echo ""
echo "--- Check if PYTHONPATH in .env ---"
grep -i PYTHONPATH .env 2>/dev/null || echo "PYTHONPATH NOT in .env"
echo ""
echo "--- ls futures_bot/ ---"
ls -la /root/MT5-PropFirm-Bot/futures_bot/ 2>/dev/null | head -10
echo ""
echo "--- Test run directly ---"
cd /root/MT5-PropFirm-Bot
PYTHONPATH=/root/MT5-PropFirm-Bot /usr/bin/python3 -c "import futures_bot.bot; print('IMPORT OK')" 2>&1
echo ""
echo "--- Test WITHOUT PYTHONPATH ---"
cd /root/MT5-PropFirm-Bot
/usr/bin/python3 -c "import futures_bot.bot; print('IMPORT OK without PYTHONPATH')" 2>&1
echo ""
echo "--- Test with -m from WorkingDirectory ---"
cd /root/MT5-PropFirm-Bot
/usr/bin/python3 -m futures_bot.bot --help 2>&1 | head -3 || echo "Exit code: $?"
echo ""
echo "--- systemctl cat ---"
systemctl cat futures-bot 2>&1
