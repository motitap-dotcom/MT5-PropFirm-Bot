# Server Connection Details - VPS PropFirmBot

## Connection Info
- **IP Address:** 77.237.234.2
- **User:** root
- **Password:** Moti0417!
- **Connection Method:** SSH (from Windows PowerShell)
- **OS:** Ubuntu Linux (Contabo VPS)

## SSH Connection Command
```bash
ssh root@77.237.234.2
```

## VNC Connection (for MT5 GUI)
- **Address:** 77.237.234.2:5900
- **Client:** RealVNC (on Windows)
- **Password:** none (no password)

## Pull & Update Commands (run on VPS after SSH)
```bash
# Step 1: Go to repo folder
cd /root/MT5-PropFirm-Bot

# Step 2: Pull latest changes
git pull origin claude/build-cfd-trading-bot-fl0ld

# Step 3: Copy updated EA files to MT5
cp -r EA/PropFirmBot/* "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot/"

# Step 4: Copy config files to MT5
cp -r configs/* "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot/"
```

## Important Paths on VPS
- **Git Repo:** /root/MT5-PropFirm-Bot
- **MT5 Install:** /root/.wine/drive_c/Program Files/MetaTrader 5/
- **EA Files:** .../MQL5/Experts/PropFirmBot/ (11 files + compiled .ex5)
- **Config Files:** .../MQL5/Files/PropFirmBot/ (6 JSON files)

## VNC Server Start (if needed)
```bash
Xvfb :99 -screen 0 1280x1024x24 &
x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw
```

## MT5 Start (if needed)
```bash
DISPLAY=:99 wine "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" &
```

## Notes
- Claude's sandbox CANNOT SSH to VPS (port 22 blocked)
- Noa runs commands via PowerShell SSH
- Noa views MT5 via RealVNC on Windows
- Claude prepares scripts/commands, Noa pastes them on VPS
