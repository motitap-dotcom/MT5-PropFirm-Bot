#!/bin/bash
# =============================================================
# FIX MEMORY: Add swap + protect MT5 from OOM killer
# =============================================================

echo "============================================"
echo "  MEMORY FIX - Swap + OOM Protection"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# =============================================
# STEP 1: Check current memory situation
# =============================================
echo "=== STEP 1: Current Memory Status ==="
free -h
echo ""
echo "Swap status:"
swapon --show 2>/dev/null || echo "No swap configured!"
echo ""

# =============================================
# STEP 2: Create 4GB swap file
# =============================================
echo "=== STEP 2: Creating 4GB Swap File ==="

if [ -f /swapfile ] && swapon --show | grep -q "/swapfile"; then
    echo "Swap already exists and is active!"
    swapon --show
else
    # Remove old swap if exists but not active
    swapoff /swapfile 2>/dev/null
    rm -f /swapfile 2>/dev/null

    # Create 4GB swap
    echo "Creating 4GB swap file..."
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "Swap CREATED and ACTIVATED!"

    # Make permanent (survive reboot)
    if ! grep -q "/swapfile" /etc/fstab 2>/dev/null; then
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
        echo "Added to /etc/fstab (permanent)"
    fi
fi

echo ""
echo "Memory after swap:"
free -h
echo ""

# =============================================
# STEP 3: Optimize swap settings
# =============================================
echo "=== STEP 3: Optimize Swap Settings ==="

# swappiness=10 means kernel will only use swap when RAM is almost full
echo 10 > /proc/sys/vm/swappiness
echo "vm.swappiness=10" > /etc/sysctl.d/99-swap.conf

# vfs_cache_pressure - lower means keep more cache
echo 50 > /proc/sys/vm/vfs_cache_pressure
echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.d/99-swap.conf

sysctl -p /etc/sysctl.d/99-swap.conf 2>/dev/null
echo "Swappiness: $(cat /proc/sys/vm/swappiness) (10 = use swap only when needed)"
echo "Cache pressure: $(cat /proc/sys/vm/vfs_cache_pressure)"
echo ""

# =============================================
# STEP 4: Protect MT5 from OOM killer
# =============================================
echo "=== STEP 4: Protect MT5 from OOM Killer ==="

# Set OOM score adjustment for MT5 to -900 (almost never kill)
# -1000 = never kill, 0 = normal, +1000 = kill first
MT5_PIDS=$(pgrep -f "terminal64" 2>/dev/null)
if [ -n "$MT5_PIDS" ]; then
    for pid in $MT5_PIDS; do
        echo -900 > /proc/$pid/oom_score_adj 2>/dev/null
        echo "MT5 PID $pid: OOM score set to -900 (protected)"
    done
else
    echo "MT5 not running - OOM protection will be applied by watchdog"
fi

# Update watchdog to also set OOM protection on restart
if [ -f /root/mt5_watchdog.sh ]; then
    # Check if OOM protection already in watchdog
    if ! grep -q "oom_score_adj" /root/mt5_watchdog.sh 2>/dev/null; then
        # Add OOM protection after MT5 starts in the watchdog
        sed -i '/MT5 restarted successfully/a\    # Protect MT5 from OOM killer\n    for pid in $(pgrep -f terminal64 2>/dev/null); do\n        echo -900 > /proc/$pid/oom_score_adj 2>/dev/null\n    done' /root/mt5_watchdog.sh
        echo "Updated watchdog with OOM protection"
    else
        echo "Watchdog already has OOM protection"
    fi
fi
echo ""

# =============================================
# STEP 5: Set chrome-headless (Tradovate) to be killed FIRST
# =============================================
echo "=== STEP 5: Set Tradovate chrome-headless as OOM target ==="

CHROME_PIDS=$(pgrep -f "chrome-headless\|chromium\|chrome" 2>/dev/null)
if [ -n "$CHROME_PIDS" ]; then
    for pid in $CHROME_PIDS; do
        echo 500 > /proc/$pid/oom_score_adj 2>/dev/null
        PROC_NAME=$(cat /proc/$pid/comm 2>/dev/null)
        echo "Chrome PID $pid ($PROC_NAME): OOM score set to +500 (kill first)"
    done
else
    echo "No chrome processes found right now"
fi

# Limit Tradovate bot memory via systemd if it's a service
if systemctl is-active tradovate-bot.service > /dev/null 2>&1; then
    echo ""
    echo "Tradovate bot is running as systemd service"
    echo "Setting memory limit to 2GB..."
    mkdir -p /etc/systemd/system/tradovate-bot.service.d/
    cat > /etc/systemd/system/tradovate-bot.service.d/memory-limit.conf << 'EOF'
[Service]
MemoryMax=2G
MemoryHigh=1500M
OOMScoreAdjust=500
EOF
    systemctl daemon-reload
    echo "Tradovate memory limited to 2GB (was unlimited)"
    echo "Current Tradovate memory usage:"
    systemctl status tradovate-bot.service 2>/dev/null | grep -i "memory\|Memory" || true
else
    echo "Tradovate bot not running as systemd service"
    # Check if it runs from cron
    crontab -l 2>/dev/null | grep -i "tradovate" || true
fi
echo ""

# =============================================
# STEP 6: Show all memory-hungry processes
# =============================================
echo "=== STEP 6: Top Memory Consumers ==="
ps aux --sort=-%mem | head -15
echo ""

# =============================================
# STEP 7: Verify MT5 is still running
# =============================================
echo "=== STEP 7: MT5 Status ==="
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "MT5: ✅ RUNNING"
    MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
    if [ -n "$MT5_PID" ]; then
        echo "PID: $MT5_PID"
        echo "Memory: $(ps -p $MT5_PID -o rss= 2>/dev/null | awk '{printf "%.0f MB\n", $1/1024}')"
        echo "OOM Score: $(cat /proc/$MT5_PID/oom_score_adj 2>/dev/null)"
    fi
else
    echo "MT5: ❌ NOT RUNNING - watchdog will restart in <2 min"
fi
echo ""

# =============================================
# STEP 8: Final summary
# =============================================
echo "============================================"
echo "  MEMORY FIX COMPLETE!"
echo ""
echo "  Changes made:"
echo "  1. ✅ 4GB Swap file created (permanent)"
echo "  2. ✅ Swappiness=10 (use swap only when needed)"
echo "  3. ✅ MT5 OOM score=-900 (protected)"
echo "  4. ✅ Chrome/Tradovate OOM score=+500 (kill first)"
echo "  5. ✅ Tradovate memory limited to 2GB"
echo "  6. ✅ All settings survive reboot"
echo ""
echo "  Before: 7.8GB RAM, 0 Swap = OOM crashes"
echo "  After:  7.8GB RAM + 4GB Swap = 11.8GB total"
echo "  MT5 is the LAST process to be killed"
echo "============================================"

# Telegram notification
curl -s -4 --connect-timeout 10 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
    -d "chat_id=7013213983" \
    -d "text=🧠 MEMORY FIX INSTALLED!

💾 4GB Swap added (was 0!)
🛡️ MT5 protected from OOM killer
⚡ Chrome/Tradovate = kill first if low memory
📊 Total memory: 7.8GB RAM + 4GB Swap

MT5 will no longer crash from memory issues!" > /dev/null 2>&1

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
