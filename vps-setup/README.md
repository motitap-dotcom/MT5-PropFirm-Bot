# VPS Setup Guide - PropFirmBot

## Option A: Ubuntu VPS (Recommended - Cheapest!)

### Step 1: Buy VPS
1. Go to **contabo.com** -> Cloud VPS
2. Choose **Cloud VPS S** (~€4.28/month) - 4 vCPU, 8GB RAM, 200GB SSD
3. Select OS: **Ubuntu 22.04** (FREE - no extra cost!)
4. Region: EU-Germany (default)
5. Pay and wait for email with login credentials (IP + password)

### Step 2: Connect via SSH
```bash
# From your computer's terminal:
ssh root@YOUR_VPS_IP

# Enter the password from your email
```

**Windows users:** Use [PuTTY](https://www.putty.org/) or Windows Terminal

### Step 3: Download & Run Setup

```bash
# Download the project
git clone https://github.com/YOUR_USERNAME/MT5-PropFirm-Bot.git
cd MT5-PropFirm-Bot/vps-setup/linux

# Make scripts executable
chmod +x *.sh

# Run everything in one command!
sudo ./setup_all.sh
```

Or run each step individually:
```bash
# Step 1: Install Wine + MT5
sudo ./01_install_mt5.sh

# Step 2: Deploy EA files to MT5
sudo ./02_deploy_ea.sh

# Step 3: Set up auto-recovery monitoring
sudo ./03_monitor.sh
```

### Step 4: Log in to Broker via VNC

After setup, you need to log in to your broker account in MT5:

```bash
# Start MT5
sudo systemctl start mt5

# Start VNC server (to see MT5 GUI)
~/PropFirmBot/start_vnc.sh
```

Then connect a VNC client (like [RealVNC](https://www.realvnc.com/en/connect/download/viewer/)) to `YOUR_VPS_IP:5900`

### Step 5: Configure EA in MT5 (via VNC)
1. Open MT5 Navigator panel (Ctrl+N)
2. Expand Expert Advisors -> PropFirmBot
3. Right-click PropFirmBot.mq5 -> Compile
4. Drag PropFirmBot onto any chart
5. Set inputs:
   - Account Size: your challenge size
   - Challenge Mode: true
   - Risk Per Trade: 0.5
6. Click OK
7. Enable "Algo Trading" button in toolbar
8. Verify smiley face appears on chart

### What the Scripts Do
| Script | Purpose |
|--------|---------|
| `01_install_mt5.sh` | Installs Wine, downloads MT5, sets up virtual display |
| `02_deploy_ea.sh` | Copies EA + config files to MT5, creates startup scripts |
| `03_monitor.sh` | Creates systemd service, watchdog cron, daily health reports |
| `setup_all.sh` | Runs all 3 scripts in one command |

### Useful Commands
```bash
sudo systemctl start mt5      # Start MT5
sudo systemctl stop mt5       # Stop MT5
sudo systemctl restart mt5    # Restart MT5
sudo systemctl status mt5     # Check if MT5 is running

tail -f ~/PropFirmBot/logs/watchdog.log     # Live watchdog log
cat ~/PropFirmBot/logs/daily_report.log     # Daily reports
```

### Monitoring
- **Watchdog**: Checks MT5 every 5 minutes, auto-restarts if crashed
- **Daily reports**: System health summary at midnight UTC
- **Systemd service**: MT5 auto-starts on VPS reboot
- **Logs**: `~/PropFirmBot/logs/`

---

## Option B: Windows VPS (More expensive)

### Step 1: Buy VPS
1. Go to **contabo.com** -> Cloud VPS
2. Choose **Cloud VPS S** - 4 vCPU, 8GB RAM, 200GB SSD
3. Select OS: **Windows Server 2022** (+€8.93/month extra!)
4. Region: EU-Germany (default)
5. Pay and wait for email with login credentials

### Step 2: Connect to VPS
- **Windows**: Open "Remote Desktop Connection" (mstsc.exe)
- **Mac**: Install "Microsoft Remote Desktop" from App Store
- Enter the IP address and password from your email

### Step 3: Run Setup Scripts (in order!)

Connect via Remote Desktop, then:

1. **Download this project** to `C:\PropFirmBot\`
2. Open PowerShell as Administrator
3. Run:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

Then run each script in order:

```powershell
# Step 1: Install MT5 + configure Windows for 24/7
.\01_install_mt5.ps1

# Step 2: Log into MT5 with your broker, then:
.\02_deploy_ea.ps1

# Step 3: Set up auto-recovery monitoring
.\03_monitor.ps1
```

### Step 4: Configure EA in MT5
1. Open MT5 Navigator panel (Ctrl+N)
2. Expand Expert Advisors -> PropFirmBot
3. Right-click PropFirmBot.mq5 -> Compile
4. Drag PropFirmBot onto any chart
5. Set inputs:
   - Account Size: your challenge size
   - Challenge Mode: true
   - Risk Per Trade: 0.5
6. Click OK
7. Enable "Algo Trading" button in toolbar
8. Verify smiley face appears on chart

### What the Scripts Do
| Script | Purpose |
|--------|---------|
| `01_install_mt5.ps1` | Downloads & installs MT5, disables sleep/hibernate, sets high-performance power plan |
| `02_deploy_ea.ps1` | Copies EA files to MT5 data folder, sets up MT5 auto-start on reboot |
| `03_monitor.ps1` | Creates watchdog (restarts MT5 if crashed), daily health reports |

### Monitoring
- **Watchdog log**: `C:\PropFirmBot\logs\watchdog.log`
- **Daily reports**: `C:\PropFirmBot\logs\daily_report.log`
- MT5 is checked every 5 minutes and auto-restarted if crashed
