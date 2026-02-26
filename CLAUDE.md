# PropFirmBot - AI Assistant Guide

## User Info
- Name: Noa (נועה)
- Language: Hebrew (עברית) - **always respond in Hebrew**
- Experience level: Not a developer - needs simple, step-by-step instructions
- Local machine: Windows (has PowerShell)

## Project Overview
PropFirmBot is an automated MetaTrader 5 Expert Advisor (EA) for trading on a FundedNext Stellar Instant prop firm account. It runs on a Linux VPS via Wine, trading forex/gold pairs with Smart Money Concepts (SMC) and EMA crossover strategies. The EA has multi-layered safety systems to protect against drawdown breaches.

## Repository Structure

```
MT5-PropFirm-Bot/
├── EA/                              # MQL5 Expert Advisor source code (12 files)
│   ├── PropFirmBot.mq5              # Main EA entry point (v3.0) - OnInit/OnTick/OnDeinit
│   ├── SignalEngine.mqh             # Signal generation (SMC + EMA crossover, multi-timeframe)
│   ├── RiskManager.mqh              # Position sizing, risk-per-trade calculations
│   ├── TradeManager.mqh             # Trade execution, trailing stops, breakeven
│   ├── Guardian.mqh                 # Master watchdog - 5 safety levels, trailing DD protection
│   ├── Dashboard.mqh                # On-chart OSD display panel
│   ├── TradeJournal.mqh             # CSV trade logging
│   ├── Notifications.mqh            # Telegram Bot API / Push / Email alerts
│   ├── NewsFilter.mqh               # Economic calendar news avoidance
│   ├── TradeAnalyzer.mqh            # Performance analytics & self-learning
│   ├── AccountStateManager.mqh      # Phase management (Challenge/Funded/Scaling)
│   └── StatusWriter.mqh             # Writes status.json for web dashboard
│
├── configs/                         # JSON configuration files (deployed to MT5 Files dir)
│   ├── account_state.json           # Current account phase & state
│   ├── challenge_rules.json         # Prop firm challenge parameters
│   ├── funded_rules.json            # Funded account rules (active config)
│   ├── risk_params.json             # Risk management parameters
│   ├── symbols.json                 # Trading symbols (EURUSD, GBPUSD, USDJPY, XAUUSD)
│   └── notifications.json           # Telegram/Push/Email notification settings
│
├── python/                          # Python backtesting & analysis tools
│   ├── data_fetcher.py              # Historical data download from MT5
│   ├── backtester.py                # Strategy backtesting engine
│   ├── optimizer.py                 # Parameter optimization + Monte Carlo simulation
│   ├── trade_analyzer.py            # Trade performance analysis
│   ├── daily_report.py              # Daily P&L reporting
│   ├── performance_report.py        # Charts & visual performance analysis
│   └── requirements.txt             # Python deps: MetaTrader5, pandas, numpy, plotly, etc.
│
├── scripts/                         # VPS maintenance & diagnostic scripts
│   ├── web_dashboard.py             # Simple web dashboard (port 8080)
│   ├── deploy_fix.sh                # Deploy EA files to MT5 data folder
│   ├── fix_and_start.sh             # Fix common issues and start MT5
│   ├── fix_and_restart.sh           # Fix and restart MT5
│   ├── clean_restart.sh             # Full clean restart of MT5
│   ├── install_mt5_linux.sh         # MT5 installation on Linux via Wine
│   ├── upgrade_wine.sh              # Wine version upgrade script
│   ├── fix_wine_version.sh          # Wine version fix
│   ├── force_wine11.sh              # Force Wine 11 installation
│   ├── verify_ea.sh                 # Verify EA is running correctly
│   ├── quick_check.sh               # Quick VPS health check
│   ├── deep_check.sh                # Deep diagnostic check
│   ├── connection_check.sh          # Network connectivity check
│   ├── network_check.sh             # Network diagnostics
│   ├── remote_check.sh              # Remote VPS check (via SSH)
│   ├── server_diag.sh               # Server diagnostics
│   └── manual_fix.sh                # Manual fix helper
│
├── dashboard/                       # Web dashboard (newer version, port 8081)
│   ├── index.html                   # Full-featured single-page dashboard UI
│   ├── server.py                    # Python HTTP server reading MT5 status.json
│   └── deploy.sh                    # Dashboard deployment script
│
├── vps-setup/                       # VPS initial setup scripts
│   ├── README.md                    # Setup documentation
│   ├── 01_install_mt5.ps1           # Windows PowerShell: install MT5
│   ├── 02_deploy_ea.ps1             # Windows PowerShell: deploy EA
│   ├── 03_monitor.ps1               # Windows PowerShell: monitoring
│   └── linux/                       # Linux VPS scripts
│       ├── setup_all.sh             # One-command full setup (runs 01→02→03)
│       ├── 01_install_mt5.sh        # Install Wine + MT5 on Ubuntu
│       ├── 02_deploy_ea.sh          # Deploy EA files to MT5 directory
│       ├── 03_monitor.sh            # Set up monitoring & watchdog
│       ├── auto_deploy_and_compile.sh # Auto-deploy + compile EA
│       ├── finish_setup.sh          # Post-install finishing touches
│       ├── install_watchdog.sh      # Watchdog systemd service installer
│       └── quick_setup.sh           # Quick setup for re-deployments
│
├── management/                      # VPS remote management API
│   ├── server.py                    # HTTP API server (port 8888, no deps)
│   └── install.sh                   # One-command systemd service installer
│
├── vps-scripts/                     # Standalone VPS health check
│   └── full-setup.sh               # Full VPS check & setup (paste-and-run)
│
├── .github/workflows/               # GitHub Actions CI
│   ├── vps-check.yml                # Triggered on push: SSH to VPS, run diagnostics
│   └── vps-fix.yml                  # Triggered on push: SSH to VPS, fix & restart MT5
│
├── logs/                            # Trade logs (gitkeep only, populated at runtime)
├── backtest_results/                # Backtest output (gitkeep only, populated at runtime)
├── vps_report.txt                   # Latest VPS status report (auto-committed by CI)
├── vps_fix_report.txt               # Latest VPS fix report (auto-committed by CI)
├── vps_status_check.sh              # Root-level VPS status check script
├── trigger-check.txt                # Push this file to trigger vps-check workflow
└── README.md                        # Project overview & installation guide
```

## Architecture & Key Patterns

### EA Module Architecture
The EA uses a modular OOP design in MQL5. Each `.mqh` file defines a class:
- **CSignalEngine** - generates buy/sell signals using SMC or EMA strategies
- **CRiskManager** - calculates lot sizes based on risk percentage and account equity
- **CTradeManager** - executes trades, manages trailing stops and breakeven
- **CGuardian** - master watchdog with 5 states: ACTIVE → CAUTION → HALTED → EMERGENCY → SHUTDOWN
- **CDashboard** - renders on-chart information panel
- **CTradeJournal** - logs trades to CSV files
- **CNotifications** - sends Telegram/Push/Email alerts via MT5 WebRequest
- **CNewsFilter** - avoids trading around high-impact news events
- **CTradeAnalyzer** - analyzes performance and adapts risk parameters
- **CAccountStateManager** - manages challenge/funded/scaling phases
- **CStatusWriter** - writes `status.json` every 3 seconds for web dashboard

### MQL5 Code Conventions
- Class names: `C` prefix (e.g., `CGuardian`, `CSignalEngine`)
- Member variables: `m_` prefix (e.g., `m_trailing_dd`, `m_equity_high_water`)
- Enums: `ENUM_` prefix (e.g., `ENUM_GUARDIAN_STATE`, `ENUM_SIGNAL_TYPE`)
- Input parameters: `Inp` prefix (e.g., `InpRiskPercent`, `InpMagicNumber`)
- File headers use MQL5-style comment blocks: `//+------------------------------------------------------------------+`
- All modules use `#property copyright "PropFirmBot"` and versioned with `#property version`

### Guardian Safety Layers (CRITICAL)
The Guardian module is the most safety-critical component. It enforces:
1. **Soft DD limits** (3.5%) → reduces lot size
2. **Critical DD limits** (5.0%) → closes all positions, halts trading
3. **Hard DD limits** (6.0%) → permanent shutdown (prop firm rule breach)
4. **Trailing drawdown** → DD calculated from equity HIGH WATER MARK, not initial balance
5. **Circuit breakers** → consecutive losses, daily trade limit, flash crash protection

### Config File System
JSON configs in `configs/` are deployed to MT5's `MQL5/Files/PropFirmBot/` directory. The EA reads these at initialization. Key config: `risk_params.json` controls all risk parameters.

## Account Details
- Prop firm: FundedNext
- Account type: Stellar Instant (direct funded - NO challenge phase)
- Account number: 11797849
- Server: FundedNext-Server
- Password: gazDE62##
- Account size: $2,000
- Profit split: 70% (up to 80%)

## FundedNext Stellar Instant Rules (CRITICAL - NEVER VIOLATE)
- **NO daily drawdown limit** (0%)
- **6% TRAILING total drawdown** (from equity high water mark, NOT from initial balance)
- NO profit target
- NO minimum trading days
- EA trading: ALLOWED
- News trading: ALLOWED (max 40% profit from single day)
- Weekend holding: ALLOWED
- Min equity at start: $1,880 ($2,000 - 6%)
- Consistency rule: max 40% of total profit in a single day

## Trading Strategy
- **Primary**: Smart Money Concepts (SMC) - H4 trend bias (EMA 50/200), M15 entry on liquidity sweeps + order blocks / fair value gaps
- **Fallback**: EMA 9/21 crossover on M15 with RSI 14 filter and H4 trend confirmation
- **Symbols**: EURUSD, GBPUSD, USDJPY, XAUUSD
- **Sessions**: London (07:00-16:00 UTC) + New York (12:00-21:00 UTC)
- **Risk**: 0.5% per trade, max 2 open positions, min 1:2 risk-reward

## Telegram Bot
- Token: 8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g
- Chat ID: 7013213983
- Bot is configured and working

## VPS Details
- Provider: Contabo
- IP: 77.237.234.2
- OS: LINUX (Ubuntu) - NOT Windows!
- SSH root password: Moti0417!
- Contabo panel password: qA4P9f3ra5bw
- Connection: `ssh root@77.237.234.2`

## VPS Current State (Updated 2026-02-26)
- MT5 is RUNNING on VPS with PropFirmBot EA ACTIVE
- FundedNext account LOGGED IN and CONNECTED (account 11797849)
- EA attached to EURUSD M15 chart
- AutoTrading is ON (green button)
- Wine + VNC working
- Bot is LIVE and trading

## Development Workflow

### Working Method
- Claude's sandbox environment CANNOT SSH to VPS (port 22 blocked)
- Noa runs commands on VPS via SSH from her Windows PowerShell
- Noa views MT5 via VNC (RealVNC client on Windows)
- Claude prepares scripts/commands, Noa pastes them into SSH

### Branching
- **Main development branch**: `claude/build-cfd-trading-bot-fl0ld`
- **Repo on VPS**: `/root/MT5-PropFirm-Bot` (same branch)
- Code changes are pushed to GitHub, then pulled on VPS

### Deployment Process
1. Edit EA/config files in the repo
2. Push to GitHub branch
3. On VPS: `cd /root/MT5-PropFirm-Bot && git pull`
4. Copy files to MT5 directory: `cp EA/* "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot/"`
5. Copy configs: `cp configs/* "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot/"`
6. Recompile in MetaEditor or restart MT5
- Or use: `bash scripts/deploy_fix.sh` for automated deployment

### CI/CD (GitHub Actions)
- **vps-check.yml**: Triggered when diagnostic scripts are pushed. SSHes to VPS, runs health checks, commits report to `vps_report.txt`
- **vps-fix.yml**: Triggered when fix scripts are pushed. SSHes to VPS, runs fix/restart, commits report to `vps_fix_report.txt`
- Trigger a check manually by editing `trigger-check.txt` and pushing

### Key File Paths on VPS
- MT5 installation: `/root/.wine/drive_c/Program Files/MetaTrader 5/`
- EA source files: `.../MQL5/Experts/PropFirmBot/` (11 .mqh + 1 .mq5 + compiled .ex5)
- Config files: `.../MQL5/Files/PropFirmBot/` (6 JSON files)
- MT5 logs: `.../MQL5/Logs/` and `.../logs/`
- VNC server: x11vnc on display :99, port 5900 (no password)
- Start VNC: `Xvfb :99 -screen 0 1280x1024x24 & x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw`

## Completed Milestones
- [x] All EA files created (PropFirmBot.mq5 + 11 .mqh modules)
- [x] Telegram bot configured and working
- [x] All configs tuned for Stellar Instant rules (6% trailing DD, no daily DD)
- [x] Guardian.mqh: trailing drawdown from equity high water mark
- [x] Risk params: 0.5% per trade, soft DD 3.5%, critical 5.0%, hard 6.0%
- [x] Linux VPS setup scripts ready (Wine + MT5 + monitoring)
- [x] VPS setup complete - Wine 11 + MT5 installed on Contabo
- [x] MT5 running on VPS, FundedNext account connected
- [x] EA compiled (PropFirmBot.ex5 - 196KB), attached to EURUSD M15
- [x] AutoTrading enabled, bot is LIVE
- [x] Web dashboard created (dashboard/ and scripts/web_dashboard.py)
- [x] Smart watchdog with Telegram alerts and auto-restart
- [x] Critical equity=0 bug fixed (status.json + diagnostics)
- [x] RiskManager bug fixed (blocked ALL trades on Stellar Instant)

## VPS Management API (Remote Control)
A Python HTTP API running on port 8888 allows remote management of the VPS without SSH.

**Files:**
- `management/server.py` - The API server (Python stdlib, no deps)
- `management/install.sh` - One-command systemd installer
- `.github/workflows/vps-manage.yml` - GitHub Actions backup trigger

**Auth token:** `pfbot_mgmt_7x9Kp2mW4vQr8sNj`
**URL:** `http://77.237.234.2:8888/api/`

**GET endpoints** (read-only, append `?token=AUTH_TOKEN`):
- `/api/status` - Full system status
- `/api/health` - Quick health check
- `/api/positions` - Open positions
- `/api/account` - Balance, equity, drawdown
- `/api/logs?source=ea&lines=50` - EA or terminal logs
- `/api/system` - CPU, RAM, disk usage
- `/api/ea-status` - EA status.json data
- `/api/config` - Current config files
- `/api/processes` - Running processes
- `/api/exec?cmd=COMMAND` - Whitelisted command execution
- `/api/ping` - No-auth health ping

**POST endpoints** (actions, append `&confirm=yes` for GET):
- `/api/restart-mt5` - Restart MetaTrader 5
- `/api/restart-vnc` - Restart VNC server
- `/api/deploy` - Git pull + deploy to MT5
- `/api/start-mt5` - Start MT5
- `/api/stop-mt5` - Stop MT5
- `/api/telegram-test` - Send test Telegram message

**Backup:** GitHub Actions `vps-manage.yml` workflow with `workflow_dispatch` for when direct HTTP is unavailable.

## Remaining Tasks
- [ ] Verify Telegram notifications from live EA
- [ ] Full watchdog installation (systemd services via install_watchdog.sh)
- [ ] Long-term performance monitoring and strategy tuning

## Critical Code Changes History
1. **Guardian.mqh**: Trailing drawdown - calculates DD from equity high water mark instead of initial balance when `m_trailing_dd=true`. Skips daily DD checks when daily DD limit is 0.
2. **PropFirmBot.mq5**: Default inputs set for Stellar Instant (PHASE_FUNDED, 0 daily DD, 6.0 total DD, Telegram credentials)
3. **RiskManager.mqh**: Fixed bug where ALL trades were blocked on Stellar Instant accounts (daily DD = 0 was treated as limit breach)
4. **StatusWriter.mqh**: Added status.json writing for web dashboard; fixed equity=0 causing SHUTDOWN
5. **All config JSONs**: Updated for 6% trailing DD, no daily limit, funded instant phase
6. **Session hours expanded**: Trading hours extended for more opportunities

## Safety Rules for AI Assistants
1. **NEVER relax drawdown limits** - the 6% trailing DD is a hard prop firm rule. Breaching it loses the account.
2. **NEVER increase risk per trade above 1%** - current 0.5% is intentionally conservative for a $2,000 account.
3. **NEVER disable Guardian** - it is the last line of defense against account breach.
4. **NEVER disable trailing drawdown** (`m_trailing_dd` must stay `true`) - Stellar Instant uses trailing DD from equity high water mark.
5. **Always test on demo first** before deploying risk-related changes to the live VPS.
6. **When preparing VPS commands** - make them copy-paste friendly since Noa is not a developer.
7. **Preserve magic number** (202502) - changing it causes the EA to lose track of its own positions.
