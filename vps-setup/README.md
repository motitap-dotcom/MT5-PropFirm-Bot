# VPS Setup Guide - PropFirmBot

## Cheapest Option: Contabo Cloud VPS - $6.49/month

### Step 1: Buy VPS
1. Go to **contabo.com** -> Cloud VPS
2. Choose **Cloud VPS S** ($6.49/month) - 4 vCPU, 8GB RAM, 200GB SSD
3. Select OS: **Windows Server 2022**
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
