#!/bin/bash
# Setup watchdog cron job on VPS
# Run this ONCE on VPS: bash /root/MT5-PropFirm-Bot/scripts/setup_watchdog.sh

echo "=== Setting up Watchdog ==="

# Make watchdog executable
chmod +x /root/MT5-PropFirm-Bot/scripts/watchdog.sh

# Create log file
touch /var/log/watchdog.log

# Add cron job (every 5 minutes)
CRON_LINE="*/5 * * * * /root/MT5-PropFirm-Bot/scripts/watchdog.sh >> /var/log/watchdog.log 2>&1"

# Check if already installed
if crontab -l 2>/dev/null | grep -q "watchdog.sh"; then
    echo "Watchdog cron already exists - updating..."
    crontab -l 2>/dev/null | grep -v "watchdog.sh" | { cat; echo "$CRON_LINE"; } | crontab -
else
    echo "Adding watchdog cron..."
    (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
fi

echo ""
echo "Cron jobs:"
crontab -l

echo ""
echo "✅ Watchdog installed! Checks every 5 minutes."
echo "   Log: /var/log/watchdog.log"
echo "   Test: bash /root/MT5-PropFirm-Bot/scripts/watchdog.sh"

echo "=== Done ==="
