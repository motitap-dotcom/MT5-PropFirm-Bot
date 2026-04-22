#!/bin/bash
# Trigger: diagnose-module-error
cd /root/MT5-PropFirm-Bot
echo "=== Module error diag $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
echo ""
echo "=== service file ==="
cat /etc/systemd/system/futures-bot.service
echo ""
echo "=== .env (without secrets) ==="
sed -E 's/=(.{3}).*/=\1***/' .env 2>/dev/null || echo "no .env"
echo ""
echo "=== .env has PYTHONPATH? ==="
grep -E "^PYTHONPATH" .env 2>/dev/null || echo "no PYTHONPATH override in .env (good)"
echo ""
echo "=== working tree root ==="
ls -la /root/MT5-PropFirm-Bot/ | head -20
echo ""
echo "=== futures_bot dir ==="
ls -la /root/MT5-PropFirm-Bot/futures_bot/ 2>/dev/null || echo "!!! futures_bot DIR MISSING !!!"
echo ""
echo "=== try importing manually ==="
cd /root/MT5-PropFirm-Bot
PYTHONPATH=/root/MT5-PropFirm-Bot /usr/bin/python3 -c "import futures_bot.bot; print('import OK')" 2>&1 | head -20
echo ""
echo "=== systemd env dump ==="
systemctl show futures-bot --property=Environment 2>&1
systemctl show futures-bot --property=EnvironmentFiles 2>&1
echo ""
echo "=== which python3 + version ==="
which python3
/usr/bin/python3 --version
echo ""
echo "=== pip packages playwright/aiohttp ==="
/usr/bin/python3 -c "import aiohttp, websockets, playwright; print('aiohttp', aiohttp.__version__, '| websockets', websockets.__version__, '| playwright: OK')" 2>&1
