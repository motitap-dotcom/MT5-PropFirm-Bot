#!/bin/bash
# Quick status check after deploy - 2026-03-04
echo "=== Quick Status - $(date) ==="
echo ""
echo "--- MT5 Process ---"
pgrep -a terminal64 || echo "MT5 NOT RUNNING"
echo ""
echo "--- EA files timestamp ---"
ls -la "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot/"*.mq5 2>/dev/null | awk '{print $6,$7,$8,$NF}'
echo ""
echo "--- Config timestamp ---"
ls -la "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot/"*.json 2>/dev/null | awk '{print $6,$7,$8,$NF}'
echo ""
echo "--- AccountState.dat exists? ---"
ls -la "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot_AccountState.dat" 2>/dev/null || echo "DELETED (good - will re-init)"
echo ""
echo "--- Status.json ---"
cat "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot/status.json" 2>/dev/null | strings
echo ""
echo "=== Done ==="
