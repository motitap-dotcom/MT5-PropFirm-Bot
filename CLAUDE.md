# PropFirmBot - Project Memory

## User Info
- Name: Noa
- Language: Hebrew - always respond in Hebrew
- Experience level: Not a developer - needs simple, clear explanations
- Local machine: Windows (PowerShell, RealVNC)

---

## IRON RULES - MANDATORY

### 1. No guessing. Ever.
- NEVER answer questions about bot status, balance, trades, or errors based on memory or previous data.
- Before EVERY answer about the bot's state: pull fresh data from VPS via the workflow.
- ALWAYS show the timestamp of the data source. Format: `[Data from: YYYY-MM-DD HH:MM UTC]`
- If the data is older than 30 minutes: warn explicitly: "**DATA IS STALE (>30 min). Fetching fresh data.**"

### 2. No confirming changes without verification.
- After deploying code or running a fix: ALWAYS run a follow-up status check to verify the change took effect.
- Never say "done" based only on the push succeeding. The workflow must complete AND the output must confirm success.

### 3. No relying on previous runs.
- Each session starts fresh. Don't assume the bot is running, the account is connected, or anything else from a previous conversation.
- First action in any session about bot status: fetch fresh data.

### 4. No direct SSH.
- Claude's sandbox blocks port 22. SSH will always fail.
- ALL VPS operations go through: edit file in repo -> push -> GitHub Actions runs on VPS -> result committed back to repo.
- Never try `ssh`, `scp`, or any direct network command to the VPS.

### 5. No destructive actions without explicit permission.
- Never kill MT5, restart services, or delete files without Noa's explicit approval.
- Always explain what a script will do BEFORE pushing it.

---

## Architecture: How This Bot Works

```
[Repo on GitHub]
      |
      | (push triggers workflow)
      v
[GitHub Actions runner]
      |
      | (SSH into VPS via sshpass + secrets)
      v
[Contabo VPS - Ubuntu + Wine]
      |
      | (Wine runs MT5 with PropFirmBot EA)
      v
[MetaTrader 5 → FundedNext broker]
      |
      | (EA writes status.json, logs, journal CSVs)
      v
[Results committed back to repo by Actions]
```

Claude edits files locally -> pushes to GitHub -> GitHub Actions SSH into VPS -> executes -> commits results back.

---

## GitHub Actions Workflows (the 4 pipelines)

### 1. `vps-command.yml` — Run any command on VPS
- **Trigger**: push that changes `commands/run.sh`
- **What it does**: Copies `commands/run.sh` to VPS, executes it via bash
- **Output file**: `commands/output.txt` (committed back by Actions)
- **Use for**: Status checks, reading logs, running arbitrary commands, diagnostics
- **How to use**: Write bash commands in `commands/run.sh`, push, wait ~60s, pull

### 2. `deploy-ea.yml` — Deploy EA code + configs to VPS
- **Trigger**: push that changes any file in `EA/**` or `configs/**`
- **What it does**: Copies all `.mq5`/`.mqh` files to VPS EA directory, copies all `.json` configs, recompiles EA with MetaEditor
- **Output file**: `deploy_report.txt` (committed back by Actions)
- **Use for**: Code changes, config updates, bug fixes in EA modules

### 3. `vps-check.yml` — Run VPS diagnostics
- **Trigger**: push that changes `trigger-check.txt`, `commands/check_status.sh`, `scripts/verify_ea.sh`, `scripts/remote_check.sh`, `scripts/deep_check.sh`, `scripts/connection_check.sh`, `scripts/network_check.sh`, or `scripts/quick_check.sh`
- **What it does**: Copies `scripts/verify_ea.sh` to VPS and runs it
- **Output file**: `vps_report.txt` (committed back by Actions)
- **Use for**: Full diagnostic check (MT5 process, connections, logs, Wine status)

### 4. `vps-fix.yml` — Fix and restart MT5
- **Trigger**: push that changes `scripts/fix_and_restart.sh`, `scripts/clean_restart.sh`, `scripts/upgrade_wine.sh`, `scripts/fix_wine_version.sh`, `scripts/force_wine11.sh`, or `scripts/install_mt5_linux.sh`
- **What it does**: Copies `scripts/install_mt5_linux.sh` to VPS and runs it (full MT5 reinstall/restart)
- **Output file**: `vps_fix_report.txt` (committed back by Actions)
- **Use for**: MT5 crashes, connection issues, Wine problems, full restart

All workflows also send Telegram notifications on completion.

---

## Commands Noa Can Ask For (and what Claude does)

| Request from Noa | What Claude does | Trigger file | Output file |
|---|---|---|---|
| "מה המצב של הבוט?" | Writes status script to `commands/run.sh`, pushes | `commands/run.sh` | `commands/output.txt` |
| "תראה לי לוגים" | Writes log-reading script to `commands/run.sh`, pushes | `commands/run.sh` | `commands/output.txt` |
| "יש טרייד פתוח?" | Writes position-check script to `commands/run.sh`, pushes | `commands/run.sh` | `commands/output.txt` |
| "תתקן את הבוט" | Edits `scripts/fix_and_restart.sh`, pushes | `scripts/fix_and_restart.sh` | `vps_fix_report.txt` |
| "תעדכן את הקוד" | Edits files in `EA/` or `configs/`, pushes | `EA/**` or `configs/**` | `deploy_report.txt` |
| "תעשה בדיקה מלאה" | Edits `scripts/verify_ea.sh` or `trigger-check.txt`, pushes | `trigger-check.txt` | `vps_report.txt` |
| "תריץ פקודה X" | Writes command X in `commands/run.sh`, pushes | `commands/run.sh` | `commands/output.txt` |

### Workflow for every request:
1. Write/edit the trigger file
2. Push to GitHub
3. Wait ~30-60 seconds for Actions to run
4. `git pull` to get the output file
5. Read the output file and present results to Noa WITH timestamp
6. If data is older than 30 minutes, warn and offer to fetch fresh data

---

## File Map — Real paths

### In this repo (local):

| Path | Purpose |
|---|---|
| `EA/PropFirmBot.mq5` | Main EA entry point |
| `EA/Guardian.mqh` | Drawdown protection (5 safety layers, trailing DD) |
| `EA/RiskManager.mqh` | Position sizing, session filter, weekend guard |
| `EA/SignalEngine.mqh` | Trading signals (EMA crossover + SMC) |
| `EA/TradeManager.mqh` | Order execution |
| `EA/Dashboard.mqh` | On-chart display |
| `EA/TradeJournal.mqh` | CSV trade logging |
| `EA/Notifications.mqh` | Telegram/Push/Email alerts |
| `EA/NewsFilter.mqh` | News event filter |
| `EA/TradeAnalyzer.mqh` | Performance analytics + self-learning |
| `EA/AccountStateManager.mqh` | Phase management (Challenge/Funded) |
| `EA/StatusWriter.mqh` | Writes status.json every tick |
| `configs/account_state.json` | Current phase config (FUNDED_INSTANT) |
| `configs/challenge_rules.json` | FundedNext rules (6% trailing DD, no daily DD) |
| `configs/funded_rules.json` | Funded phase risk settings |
| `configs/risk_params.json` | Risk parameters (lot size, DD guards, session times) |
| `configs/notifications.json` | Telegram token/chat ID, notification triggers |
| `configs/symbols.json` | Traded symbols: EURUSD, GBPUSD, USDJPY, XAUUSD |
| `commands/run.sh` | Script to execute on VPS (trigger for vps-command) |
| `commands/check_status.sh` | Status check script |
| `commands/output.txt` | Output from last VPS command (read-only, written by Actions) |
| `scripts/fix_and_restart.sh` | MT5 fix + restart script |
| `scripts/install_mt5_linux.sh` | Full MT5 install script (used by vps-fix) |
| `scripts/verify_ea.sh` | Diagnostic script (used by vps-check) |
| `trigger-check.txt` | Edit to trigger vps-check workflow |
| `deploy_report.txt` | Output from last EA deploy (written by Actions) |
| `vps_report.txt` | Output from last VPS check (written by Actions) |
| `vps_fix_report.txt` | Output from last VPS fix (written by Actions) |
| `status/status.json` | EA status snapshot (written by StatusWriter.mqh) |

### On VPS:

| Path | Purpose |
|---|---|
| `/root/MT5-PropFirm-Bot/` | Repo clone on VPS |
| `/root/.wine/drive_c/Program Files/MetaTrader 5/` | MT5 installation |
| `.../MQL5/Experts/PropFirmBot/` | EA files (.mq5, .mqh, .ex5) |
| `.../MQL5/Files/PropFirmBot/` | Config JSONs + status.json |
| `.../MQL5/Logs/YYYYMMDD.log` | EA logs (daily files) |
| `/root/.wine/drive_c/Program Files/MetaTrader 5/logs/` | Terminal logs |

---

## Account Details

- Prop firm: FundedNext
- Account type: Stellar Instant (direct funded, NO challenge)
- Account number: 11797849
- Server: FundedNext-Server
- Password: gazDE62##
- Account size: $2,000
- Profit split: 70% (up to 80%)

### FundedNext Stellar Instant Rules (CRITICAL)
- NO daily drawdown limit (0%)
- 6% TRAILING total drawdown (from equity HIGH WATER MARK, not from initial balance)
- NO profit target
- NO minimum trading days
- EA trading: ALLOWED
- News trading: ALLOWED (max 40% profit from single day)
- Weekend holding: ALLOWED
- Min equity: $1,880 ($2,000 - 6%)
- Consistency rule: max 40% of total profit in a single day

---

## Telegram Bot
- Token: 8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g
- Chat ID: 7013213983
- Status: Configured in EA but BLOCKED in MT5 (needs "Allow WebRequest" for api.telegram.org in MT5 Tools > Options > Expert Advisors)

## VPS Details
- Provider: Contabo
- IP: 77.237.234.2
- OS: Ubuntu Linux (Wine + MT5)
- SSH: root@77.237.234.2 (password: Moti0417!)
- Contabo panel password: qA4P9f3ra5bw
- VNC: port 5900, no password (RealVNC)
- Display: Xvfb :99, x11vnc

## Noa's Tools (for manual access)
- VNC: RealVNC on Windows → 77.237.234.2:5900
- SSH: PowerShell → `ssh root@77.237.234.2`
- Terminal: PowerShell on Windows

---

## EA Architecture (12 modules)

| Module | File | Role |
|---|---|---|
| Main EA | `PropFirmBot.mq5` | Entry point, OnInit/OnTick/OnDeinit, initializes all modules |
| Guardian | `Guardian.mqh` | MASTER WATCHDOG - 5 safety layers (ACTIVE→CAUTION→HALTED→EMERGENCY→SHUTDOWN), trailing DD from equity high water mark |
| Risk Manager | `RiskManager.mqh` | Position sizing, spread filter, session filter (London 07-11, NY 12-16 UTC), weekend guard (close Friday 20:00 UTC) |
| Signal Engine | `SignalEngine.mqh` | Two strategies: EMA crossover (fallback) + SMC/order blocks (primary). Multi-timeframe: M15 entry, H4 bias |
| Trade Manager | `TradeManager.mqh` | Order execution via CTrade, slippage 20 points |
| Dashboard | `Dashboard.mqh` | On-chart display: balance, equity, DD, positions, guardian state |
| Trade Journal | `TradeJournal.mqh` | CSV logging: `PropFirmBot_Journal_YYYYMMDD.csv` |
| Notifications | `Notifications.mqh` | Telegram, push, email alerts |
| News Filter | `NewsFilter.mqh` | Blocks trading around high-impact news events |
| Trade Analyzer | `TradeAnalyzer.mqh` | Win/loss tracking, performance analytics, self-learning risk adjustment |
| Account State | `AccountStateManager.mqh` | Phase management (Challenge vs Funded), loads rules from configs |
| Status Writer | `StatusWriter.mqh` | Writes `status.json` every tick for external monitoring |

### Guardian Safety Layers:
1. **ACTIVE** (0) — All systems go
2. **CAUTION** (1) — Approaching limits (soft DD 3.5%), reduce risk
3. **HALTED** (2) — No new trades, manage existing only (critical DD 5.0%)
4. **EMERGENCY** (3) — Close everything NOW
5. **SHUTDOWN** (4) — Permanent stop (hard DD 6.0%)

### Trading Parameters (from configs):
- Risk per trade: 0.5% (max 0.75%)
- Max positions: 2
- Max daily trades: 6
- Min R:R ratio: 2.0
- Symbols: EURUSD, GBPUSD, USDJPY, XAUUSD (all M15 entry, H4 higher TF)
- Sessions: London 07:00-11:00 UTC, New York 12:00-16:00 UTC
- Weekend: Close all positions Friday 20:00 UTC

---

## Known Bugs (from TEST_COVERAGE_ANALYSIS.md)

1. **CRITICAL**: RiskManager.mqh `IsTotalDrawdownOK()` uses fixed DD calculation, not trailing. Guardian.mqh does it correctly. They can disagree.
2. **HIGH**: Python backtester DD calculation doesn't match EA (uses fixed DD, not trailing).
3. **HIGH**: Python backtester ignores 40% consistency rule.
4. **MEDIUM**: Backtester pip values are hardcoded approximations.
5. **LOW**: Dashboard hardcodes wrong DD limits ("5% daily, 10% total" instead of "0% daily, 6% trailing").
6. **KNOWN ISSUE**: Telegram notifications blocked in MT5 (needs WebRequest whitelist for api.telegram.org).

---

## How to Resume Work
1. Don't assume anything from previous sessions
2. Fetch fresh status: write check script to `commands/run.sh`, push, pull results
3. Read `commands/output.txt` for current state
4. Check `status/status.json` for last EA-written snapshot (may be stale)
5. All output files have timestamps - always verify freshness
