# PropFirmBot - Project Memory

## ⚠️⚠️⚠️ MANDATORY WORKFLOW - ABSOLUTE REQUIREMENT ⚠️⚠️⚠️

### 🚫 NEVER DO THESE:
- **NEVER** try to SSH/connect directly to VPS - it WILL fail (port 22 blocked from sandbox)
- **NEVER** ask Noa to run commands manually - use the workflow
- **NEVER** suggest direct VPS operations as an alternative
- **NEVER** try `curl`, `nc`, `telnet`, or any direct network connection to VPS

### ✅ THE ONLY WAY TO INTERACT WITH VPS:
```
1. Write/edit a file in the repo (commands/run.sh, EA/*, configs/*, scripts/*)
2. git add + git commit + git push
3. GitHub Actions detects the push, SSHs to VPS, runs the command
4. GitHub Actions commits the output back to the repo
5. git pull to read the results
```

**This is called "Push & Listen" and is the ONLY method available.**

### Step-by-Step for Every VPS Operation:

#### To run any command on VPS:
```bash
# 1. Write the command to commands/run.sh
# 2. Push:
git add commands/run.sh && git commit -m "description" && git push -u origin <branch-name>
# 3. Wait 60-90 seconds
# 4. Pull results:
git pull origin <branch-name>
# 5. Read output:
cat commands/output.txt
```

#### To check VPS status:
```bash
# Edit commands/check_status.sh → push → read commands/output.txt
```

#### To deploy EA code changes:
```bash
# Edit files in EA/ or configs/ → push → read deploy_report.txt
```

#### To fix/restart MT5:
```bash
# Edit scripts/fix_and_restart.sh → push → read vps_fix_report.txt
```

### Workflow Triggers (GitHub Actions):

| Workflow | Trigger File(s) | Output File | YAML |
|----------|-----------------|-------------|------|
| **vps-command** | `commands/run.sh` | `commands/output.txt` | `.github/workflows/vps-command.yml` |
| **vps-check** | `commands/check_status.sh`, `scripts/verify_ea.sh`, `scripts/*.sh` | `vps_report.txt` | `.github/workflows/vps-check.yml` |
| **deploy-ea** | `EA/**`, `configs/**` | `deploy_report.txt` | `.github/workflows/deploy-ea.yml` |
| **vps-fix** | `scripts/fix_and_restart.sh`, `scripts/clean_restart.sh`, `scripts/install_mt5_linux.sh` | `vps_fix_report.txt` | `.github/workflows/vps-fix.yml` |

### Troubleshooting Workflows:
- If `git pull` shows no new output after 2 minutes: workflow may have failed - check GitHub Actions tab
- Workflows work on ANY branch (no branch restrictions)
- Each workflow pushes results back to the SAME branch that triggered it
- If workflow doesn't trigger: make sure the file path matches the `paths:` filter in the YAML exactly
- The file content MUST actually change for GitHub to detect a push (add a timestamp comment if needed)

---

## User Info
- Name: Noa (נועה)
- Language: Hebrew (עברית) - always respond in Hebrew
- Experience level: Not a developer - needs simple, step-by-step instructions
- Local machine: Windows (has PowerShell)

## Account Details
- Prop firm: FundedNext
- Account type: Stellar Instant (direct funded - NO challenge phase)
- Account number: 11797849
- Server: FundedNext-Server
- Password: gazDE62##
- Account size: $2,000
- Profit split: 70% (up to 80%)

## FundedNext Stellar Instant Rules (CRITICAL)
- NO daily drawdown limit (0%)
- 6% TRAILING total drawdown (from equity high water mark, NOT from initial balance)
- NO profit target
- NO minimum trading days
- EA trading: ALLOWED
- News trading: ALLOWED (max 40% profit from single day)
- Weekend holding: ALLOWED
- Min equity at start: $1,880 ($2,000 - 6%)
- Consistency rule: max 40% of total profit in a single day

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
- Connection method: SSH (not RDP!)
- Connect: ssh root@77.237.234.2
- **Claude CANNOT use SSH directly** - must use Push & Listen workflow only!

## What's Been Done
- [x] All EA files created (PropFirmBot.mq5 + 10 .mqh modules)
- [x] Telegram bot configured with token and chat ID
- [x] All configs updated for Stellar Instant rules (trailing DD, no daily DD)
- [x] Guardian.mqh modified for trailing drawdown (equity high water mark)
- [x] Risk params set: 0.5% per trade, soft DD 3.5%, critical 5.0%, hard 6.0%
- [x] Linux VPS setup scripts ready (Wine + MT5 + monitoring)
- [x] Deploy script updated with all 11 EA files
- [x] VPS setup complete - Wine + MT5 installed on Contabo VPS
- [x] MT5 running on VPS (accessible via VNC)
- [x] FundedNext account connected in MT5 (account 11797849, FundedNext-Server)
- [x] MT5 shows connected and working on VPS
- [x] GitHub Actions workflows configured (deploy, check, fix, run commands)

## VPS Current State (Updated 2026-03-04)
- MT5 was last seen NOT RUNNING (needs restart)
- Last known balance: $1,989.74 (equity: $1,992.87)
- Last known DD: 0.11%
- Had 1 open position (USDJPY BUY)
- FundedNext account LOGGED IN (account 11797849)
- EA was attached to EURUSD M15 chart
- Wine + VNC were working

## Critical Code Changes Made
1. **Guardian.mqh**: Added trailing drawdown - calculates DD from equity high water mark instead of initial balance when `m_trailing_dd=true`. Skips daily DD checks when daily DD limit is 0.
2. **PropFirmBot.mq5**: Default inputs set for Stellar Instant (PHASE_FUNDED, 0 daily DD, 6.0 total DD, Telegram credentials)
3. **All config JSONs**: Updated for 6% trailing DD, no daily limit, funded instant phase

## EA Modules (11 files)
1. PropFirmBot.mq5 - Main EA
2. SignalEngine.mqh - Trading signals (multi-timeframe)
3. RiskManager.mqh - Position sizing & risk
4. TradeManager.mqh - Trade execution
5. Guardian.mqh - Drawdown protection (5 safety layers)
6. Dashboard.mqh - On-chart display
7. TradeJournal.mqh - Trade logging
8. Notifications.mqh - Telegram/Push/Email alerts
9. NewsFilter.mqh - News event filtering
10. TradeAnalyzer.mqh - Performance analytics
11. AccountStateManager.mqh - Phase management (Challenge/Funded/Scaling)

## Working Method (REPEAT - READ THIS EVERY SESSION)
- Claude's environment CANNOT SSH to VPS (port 22 blocked from sandbox)
- ALL VPS operations MUST go through: edit file → push to repo → GitHub Actions runs on VPS → results committed back to repo → git pull to read
- Available workflows: vps-command (run anything), deploy-ea (update code), vps-check (status), vps-fix (restart)
- After pushing, wait ~60-90 seconds then git pull to read results
- If results don't appear after 2 minutes, the workflow may have failed
- Noa can also SSH manually from PowerShell if needed: ssh root@77.237.234.2

## Noa's Tools
- VNC client: RealVNC (on Windows)
- Terminal: PowerShell (Windows) → SSH to VPS
- SSH: ssh root@77.237.234.2 (password: Moti0417!)

## How to Resume Work
- VPS at 77.237.234.2
- VNC for MT5 GUI: connect to 77.237.234.2:5900 (no password, via RealVNC)
- Repo on VPS: /root/MT5-PropFirm-Bot
- MT5 installed at: /root/.wine/drive_c/Program Files/MetaTrader 5/
- EA files at: .../MQL5/Experts/PropFirmBot/ (all 11 files + .ex5 compiled)
- Config files at: .../MQL5/Files/PropFirmBot/ (6 JSON files)
- VNC server: x11vnc on display :99, port 5900
- Start VNC: Xvfb :99 -screen 0 1280x1024x24 & x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw
