#!/bin/bash
#=============================================================================
# PropFirmBot - MT5 Installer for Ubuntu VPS
# Run: chmod +x 01_install_mt5.sh && sudo ./01_install_mt5.sh
#=============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  PropFirmBot - MT5 Ubuntu Setup${NC}"
echo -e "${CYAN}  Step 1: Install Wine + MetaTrader 5${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# --- Check root ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Please run as root: sudo ./01_install_mt5.sh${NC}"
    exit 1
fi

# Get the actual user (not root)
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(eval echo "~$ACTUAL_USER")

# --- Create working directories ---
BOT_DIR="$ACTUAL_HOME/PropFirmBot"
LOGS_DIR="$BOT_DIR/logs"
DOWNLOAD_DIR="$BOT_DIR/downloads"

for dir in "$BOT_DIR" "$LOGS_DIR" "$DOWNLOAD_DIR"; do
    mkdir -p "$dir"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$dir"
    echo -e "${GREEN}[OK] Created: $dir${NC}"
done

# --- Update system ---
echo ""
echo -e "${YELLOW}[1/5] Updating system packages...${NC}"
apt-get update -y
apt-get upgrade -y
echo -e "${GREEN}[OK] System updated${NC}"

# --- Install dependencies ---
echo ""
echo -e "${YELLOW}[2/5] Installing dependencies...${NC}"
apt-get install -y \
    wget \
    curl \
    software-properties-common \
    gnupg2 \
    xvfb \
    x11vnc \
    xdotool \
    cabextract \
    winbind \
    unzip \
    python3 \
    python3-pip \
    python3-venv \
    htop \
    screen \
    cron
echo -e "${GREEN}[OK] Dependencies installed${NC}"

# --- Install Wine ---
echo ""
echo -e "${YELLOW}[3/5] Installing Wine...${NC}"

# Enable 32-bit architecture
dpkg --add-architecture i386

# Add Wine repository
mkdir -pm755 /etc/apt/keyrings
wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key 2>/dev/null || true

# Detect Ubuntu version
UBUNTU_VERSION=$(lsb_release -cs 2>/dev/null || echo "jammy")
wget -NP /etc/apt/sources.list.d/ "https://dl.winehq.org/wine-builds/ubuntu/dists/${UBUNTU_VERSION}/winehq-${UBUNTU_VERSION}.sources" 2>/dev/null || true

# Try to install from WineHQ repo first, fallback to default
apt-get update -y 2>/dev/null || true

if apt-get install -y --install-recommends winehq-stable 2>/dev/null; then
    echo -e "${GREEN}[OK] Wine (stable) installed from WineHQ${NC}"
elif apt-get install -y wine wine64 wine32 2>/dev/null; then
    echo -e "${GREEN}[OK] Wine installed from Ubuntu repos${NC}"
else
    # Last resort: install wine from default repos
    apt-get install -y wine 2>/dev/null || {
        echo -e "${RED}[ERROR] Failed to install Wine${NC}"
        echo -e "${YELLOW}Try manually: sudo apt install wine${NC}"
        exit 1
    }
    echo -e "${GREEN}[OK] Wine installed${NC}"
fi

# --- Initialize Wine prefix ---
echo ""
echo -e "${YELLOW}[4/5] Initializing Wine environment...${NC}"

# Set Wine to Windows 10 mode
su - "$ACTUAL_USER" -c "WINEARCH=win64 WINEPREFIX=$ACTUAL_HOME/.wine wineboot --init" 2>/dev/null || true
sleep 5

# Install winetricks for font support
wget -O /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks 2>/dev/null || true
chmod +x /usr/local/bin/winetricks 2>/dev/null || true

# Install required components via winetricks
su - "$ACTUAL_USER" -c "WINEPREFIX=$ACTUAL_HOME/.wine winetricks -q corefonts vcrun2019" 2>/dev/null || true

echo -e "${GREEN}[OK] Wine environment initialized${NC}"

# --- Download and install MT5 ---
echo ""
echo -e "${YELLOW}[5/5] Downloading and installing MetaTrader 5...${NC}"

MT5_INSTALLER="$DOWNLOAD_DIR/mt5setup.exe"
MT5_URL="https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"

wget -O "$MT5_INSTALLER" "$MT5_URL" 2>/dev/null
chown "$ACTUAL_USER:$ACTUAL_USER" "$MT5_INSTALLER"
echo -e "${GREEN}[OK] MT5 downloaded${NC}"

# Install MT5 via Wine with virtual display
echo -e "${YELLOW}Installing MT5 (this may take a few minutes)...${NC}"
su - "$ACTUAL_USER" -c "
    export DISPLAY=:99
    export WINEPREFIX=$ACTUAL_HOME/.wine
    Xvfb :99 -screen 0 1024x768x16 &
    XVFB_PID=\$!
    sleep 2
    wine '$MT5_INSTALLER' /auto 2>/dev/null
    sleep 30
    kill \$XVFB_PID 2>/dev/null || true
" 2>/dev/null || true

echo -e "${GREEN}[OK] MT5 installation completed${NC}"

# --- Find MT5 installation ---
MT5_PATH=""
POSSIBLE_PATHS=(
    "$ACTUAL_HOME/.wine/drive_c/Program Files/MetaTrader 5"
    "$ACTUAL_HOME/.wine/drive_c/Program Files (x86)/MetaTrader 5"
)

for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -f "$path/terminal64.exe" ]; then
        MT5_PATH="$path"
        break
    fi
done

if [ -n "$MT5_PATH" ]; then
    echo -e "${GREEN}[OK] MT5 found at: $MT5_PATH${NC}"
    echo "$MT5_PATH" > "$BOT_DIR/mt5_path.txt"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$BOT_DIR/mt5_path.txt"
else
    echo -e "${YELLOW}[WARN] MT5 path not auto-detected.${NC}"
    echo -e "${YELLOW}It might still be installing. Check: find ~/.wine -name terminal64.exe${NC}"
fi

# --- Create Xvfb service for headless operation ---
echo ""
echo -e "${YELLOW}Setting up virtual display service...${NC}"

cat > /etc/systemd/system/xvfb.service << 'XVFB_EOF'
[Unit]
Description=X Virtual Frame Buffer for MT5
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/Xvfb :99 -screen 0 1280x1024x24
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
XVFB_EOF

systemctl daemon-reload
systemctl enable xvfb.service
systemctl start xvfb.service
echo -e "${GREEN}[OK] Virtual display service created (DISPLAY=:99)${NC}"

# --- Configure system for 24/7 operation ---
echo ""
echo -e "${YELLOW}Configuring system for 24/7 operation...${NC}"

# Disable unattended upgrades auto-restart
if [ -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
    sed -i 's/Unattended-Upgrade "1"/Unattended-Upgrade "0"/' /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null || true
fi
echo -e "${GREEN}[OK] Auto-restart disabled${NC}"

# Set timezone to UTC
timedatectl set-timezone UTC
echo -e "${GREEN}[OK] Timezone set to UTC${NC}"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  MT5 Installation Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${CYAN}NEXT STEPS:${NC}"
echo -e "1. Run: ${YELLOW}sudo ./02_deploy_ea.sh${NC}"
echo -e "2. Then start MT5 to log in to your broker"
echo ""
