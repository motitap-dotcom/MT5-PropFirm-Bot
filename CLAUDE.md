# TradeDay Futures Bot - Project Memory

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
- Never kill the bot, restart services, or delete files without Noa's explicit approval.
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
[Contabo VPS - Ubuntu]
      |
      | (Python bot connects to Tradovate API)
      v
[Tradovate API → TradeDay account]
      |
      | (Bot writes status.json, logs)
      v
[Results committed back to repo by Actions]
```

Claude edits files locally -> pushes to GitHub -> GitHub Actions SSH into VPS -> executes -> commits results back.

---

## GitHub Actions Workflows (4 pipelines)

### 1. `vps-command.yml` — Run any command on VPS
- **Trigger**: push that changes `commands/run.sh`
- **What it does**: Executes `commands/run.sh` on VPS
- **Output file**: `commands/output.txt`
- **Use for**: Status checks, reading logs, diagnostics

### 2. `deploy-bot.yml` — Deploy bot code + configs to VPS
- **Trigger**: push that changes `futures_bot/**`, `configs/**`, or `requirements.txt`
- **What it does**: Pulls code, installs deps, restarts bot service
- **Output file**: `deploy_report.txt`
- **Use for**: Code changes, config updates, bug fixes

### 3. `vps-check.yml` — Run VPS diagnostics
- **Trigger**: push that changes `trigger-check.txt` or `scripts/check_bot.sh`
- **What it does**: Runs `scripts/check_bot.sh` on VPS
- **Output file**: `vps_report.txt`
- **Use for**: Full diagnostic check

### 4. `vps-fix.yml` — Fix and restart bot
- **Trigger**: push that changes `scripts/fix_and_restart.sh` or `scripts/install_bot.sh`
- **What it does**: Stops bot, pulls latest, restarts service
- **Output file**: `vps_fix_report.txt`
- **Use for**: Bot crashes, connection issues, restarts

All workflows send Telegram notifications on completion.

---

## Commands Noa Can Ask For

| Request from Noa | What Claude does | Trigger file | Output file |
|---|---|---|---|
| "מה המצב של הבוט?" | Writes status script to `commands/run.sh`, pushes | `commands/run.sh` | `commands/output.txt` |
| "תראה לי לוגים" | Writes log-reading script to `commands/run.sh`, pushes | `commands/run.sh` | `commands/output.txt` |
| "יש טרייד פתוח?" | Writes position-check script to `commands/run.sh`, pushes | `commands/run.sh` | `commands/output.txt` |
| "תתקן את הבוט" | Edits `scripts/fix_and_restart.sh`, pushes | `scripts/fix_and_restart.sh` | `vps_fix_report.txt` |
| "תעדכן את הקוד" | Edits files in `futures_bot/` or `configs/`, pushes | `futures_bot/**` or `configs/**` | `deploy_report.txt` |
| "תעשה בדיקה מלאה" | Edits `trigger-check.txt`, pushes | `trigger-check.txt` | `vps_report.txt` |
| "תריץ פקודה X" | Writes command X in `commands/run.sh`, pushes | `commands/run.sh` | `commands/output.txt` |

### Workflow for every request (MUST FOLLOW):
1. Write/edit the trigger file
2. Push to GitHub (to the correct branch: `claude/fix-bot-functionality-h1Sb3`)
3. Wait ~90-120 seconds for Actions to run and push output back
4. `git pull` to get the output file (`commands/output.txt`)
5. Read `commands/output.txt` and present results to Noa WITH timestamp
6. If data is older than 30 minutes, warn and offer to fetch fresh data
7. **NEVER ask Noa to check GitHub Actions manually** - always pull and read the output file yourself
8. If `git pull` shows no changes after 120s, wait another 60s and try again

---

## File Map — Real paths

### In this repo (local):

| Path | Purpose |
|---|---|
| `futures_bot/bot.py` | Main bot entry point |
| `futures_bot/core/tradovate_client.py` | Tradovate REST + WebSocket API client |
| `futures_bot/core/guardian.py` | MASTER WATCHDOG - 5 safety layers, TradeDay rules enforcement |
| `futures_bot/core/risk_manager.py` | Position sizing, session filter, contract specs |
| `futures_bot/core/news_filter.py` | TradeDay restricted events filter |
| `futures_bot/core/notifier.py` | Telegram notifications |
| `futures_bot/core/status_writer.py` | Writes status.json for monitoring |
| `futures_bot/strategies/vwap_mean_reversion.py` | Primary strategy: VWAP + RSI mean reversion |
| `futures_bot/strategies/orb_breakout.py` | Secondary strategy: Opening Range Breakout |
| `configs/bot_config.json` | Main bot configuration (all parameters) |
| `configs/restricted_events.json` | TradeDay restricted news events calendar |
| `commands/run.sh` | Script to execute on VPS (trigger for vps-command) |
| `commands/output.txt` | Output from last VPS command |
| `scripts/check_bot.sh` | Bot diagnostic script |
| `scripts/fix_and_restart.sh` | Fix + restart script |
| `scripts/install_bot.sh` | Install bot as systemd service |
| `trigger-check.txt` | Edit to trigger vps-check workflow |
| `status/status.json` | Bot status snapshot |
| `logs/bot.log` | Bot log file (on VPS) |
| `requirements.txt` | Python dependencies |

### On VPS:

| Path | Purpose |
|---|---|
| `/root/MT5-PropFirm-Bot/` | Repo clone on VPS |
| `/root/MT5-PropFirm-Bot/futures_bot/` | Bot Python code |
| `/root/MT5-PropFirm-Bot/configs/` | Configuration files |
| `/root/MT5-PropFirm-Bot/logs/bot.log` | Bot log file |
| `/root/MT5-PropFirm-Bot/status/status.json` | Status snapshot |
| `/root/MT5-PropFirm-Bot/.env` | Environment secrets (Tradovate, Telegram) |

---

## Account Details

- Prop firm: TradeDay
- Account type: $50K Intraday Evaluation
- Account ID: ELTDER260326211630296397
- Platform: Tradovate
- Tradovate username: stored in GitHub Secrets (`TRADOVATE_USER`)
- Tradovate password: stored in GitHub Secrets (`TRADOVATE_PASS`)

### TradeDay $50K Intraday Rules (CRITICAL)
- **Max Drawdown**: $2,000 (balance cannot drop below $48,000)
- **Profit Target**: $3,000
- **Min Trading Days**: 5
- **Consistency Rule**: No single day > 30% of total profit (max ~$900/day)
- **Position Limit**: 5 contracts / 50 micro contracts
- **Intraday Only**: ALL positions must be closed before end of day
- **Restricted Events**: Must flatten before certain news events (see calendar)
- Automated trading: ALLOWED
- No time limit to pass

---

## Telegram Bot
- Token: stored in GitHub Secrets (`TELEGRAM_TOKEN`)
- Chat ID: stored in GitHub Secrets (`TELEGRAM_CHAT_ID`)

## VPS Details
- Provider: Contabo
- IP: stored in GitHub Secrets (`VPS_HOST`)
- OS: Ubuntu Linux
- SSH: stored in GitHub Secrets (`VPS_USER`, `VPS_PASSWORD`)
- VNC: port 5900 (RealVNC)

## Tradovate Auth Method
- **Web-style auth**: No API key subscription needed
- Uses `appId="tradovate_trader(web)"`, `cid=8`, `sec=""`
- First login from new IP requires CAPTCHA (solve once via `get_token.py`)
- After that, token auto-renews via `/auth/renewaccesstoken`
- Token saved to `configs/.tradovate_token.json`
- Can also set `TRADOVATE_ACCESS_TOKEN` in `.env` as override

## GitHub Secrets Needed
- `VPS_HOST`, `VPS_USER`, `VPS_PASSWORD` — VPS access
- `TRADOVATE_USER`, `TRADOVATE_PASS` — Tradovate login
- `TELEGRAM_TOKEN`, `TELEGRAM_CHAT_ID` — Telegram notifications
- `TRADOVATE_ACCESS_TOKEN` — (optional) Pre-obtained token from CAPTCHA flow

---

## Bot Architecture (Python)

| Module | File | Role |
|---|---|---|
| Main Bot | `futures_bot/bot.py` | Entry point, main loop, strategy coordination |
| Tradovate Client | `core/tradovate_client.py` | REST + WebSocket API, orders, market data |
| Guardian | `core/guardian.py` | MASTER WATCHDOG - 5 states, enforces ALL TradeDay rules |
| Risk Manager | `core/risk_manager.py` | Position sizing, session times, contract specs |
| News Filter | `core/news_filter.py` | Blocks trading around restricted events |
| Notifier | `core/notifier.py` | Telegram alerts (trades, guardian, daily summary) |
| Status Writer | `core/status_writer.py` | Writes status.json for monitoring |
| VWAP Strategy | `strategies/vwap_mean_reversion.py` | Primary: VWAP + RSI mean reversion (60-70% win rate) |
| ORB Strategy | `strategies/orb_breakout.py` | Secondary: Opening Range Breakout (trend days) |

### Guardian Safety Layers:
1. **ACTIVE** (0) — All systems go
2. **CAUTION** (1) — 60% of max DD used, reduce risk
3. **HALTED** (2) — 80% of max DD used, no new trades
4. **EMERGENCY** (3) — 90% of max DD used, close everything NOW
5. **SHUTDOWN** (4) — Max DD breached or evaluation passed

### Trading Strategy:
- **Primary**: VWAP Mean Reversion (most days - range days)
- **Secondary**: ORB Breakout (trend days - auto-detected at 11:00 ET)
- **Symbols**: MES (Micro S&P 500), MNQ (Micro Nasdaq), MCL (Micro Crude), MGC (Micro Gold), MYM (Micro Dow), M2K (Micro Russell)
- **Timeframe**: 5-minute bars
- **Session**: 9:30-15:30 ET (no overnight positions)
- **Dead Zone**: 12:00-13:30 ET (reduced size)

### Risk Parameters:
- Max risk per trade: $150
- Max daily loss: $400
- Max daily profit: $900 (consistency rule)
- Max daily trades: 6
- Max positions: 3
- Max contracts per trade: 5 micro

---

## How to Resume Work
1. Don't assume anything from previous sessions
2. Fetch fresh status: write check script to `commands/run.sh`, push, pull results
3. Read `commands/output.txt` for current state
4. Check `status/status.json` for last bot-written snapshot (may be stale)
5. All output files have timestamps - always verify freshness

---

## Operations Guide - How the Bot is Managed

### Active Branch
- **Current working branch**: `claude/fix-bot-functionality-h1Sb3`
- All workflows reference this branch
- `vps-command.yml` has this branch HARDCODED (lines 35-36, 50-51, 55)
- Other workflows use `${{ github.ref_name }}` (auto-detect)

### Token Management System
The Tradovate token is the most critical piece. Here's how it works:

**Token flow:**
1. Token obtained via CAPTCHA (one-time manual) or user/password auth
2. Saved to 3 places: `configs/.tradovate_token.json`, `.env`, systemd drop-in
3. Background renewal task runs every **4 hours** (`start_token_renewal_loop()` in `tradovate_client.py`)
4. `_ensure_token()` also checks before every API call (renews if < 2h remaining)
5. `_renew_token()` retries 3 times with backoff on failure
6. On renewal, token is saved to all 3 locations including systemd drop-in

**Token storage locations (all must be in sync):**
| Location | Purpose | Updated by |
|---|---|---|
| `configs/.tradovate_token.json` | Primary - loaded on bot start | `_save_token()` |
| `.env` → `TRADOVATE_ACCESS_TOKEN` | Backup - used if token file missing | `_save_token()` |
| `/etc/systemd/system/futures-bot.service.d/env.conf` | systemd env - used on service restart | `_save_token()` |

**Token lifetime**: ~24 hours from Tradovate. Bot renews every 4 hours.

### Systemd Service
- Service name: `futures-bot`
- Config: `/etc/systemd/system/futures-bot.service`
- Drop-in: `/etc/systemd/system/futures-bot.service.d/env.conf` (credentials + token)
- WorkingDirectory: `/root/MT5-PropFirm-Bot`
- Restart: on-failure, every 30s
- **CRITICAL**: Drop-in env.conf values MUST have proper quoting: `Environment="KEY=value"`

### VPS Command Workflow - Important Notes
- `commands/run.sh` is the trigger file - ANY push that changes it triggers the workflow
- The workflow does `git reset --hard` on VPS BEFORE running the script
- **NEVER put `git reset --hard` inside `commands/run.sh`** - it overwrites `output.txt` and results are lost
- Keep scripts SHORT (<60 lines) - long scripts may timeout and fail to return output
- Output captured in `commands/output.txt` via SCP from VPS, then committed back

---

## Troubleshooting Guide - Known Issues & Fixes

### Issue 1: "Authentication failed: Incorrect username or password"
**Root cause**: Usually means the Tradovate token expired AND CAPTCHA is required from VPS IP.
**How to identify**: Log shows both:
- `Pre-set token from environment is expired/invalid`
- `Authentication failed: Incorrect username or password`
**Quick fix**:
1. Ask Noa to log into https://trader.tradovate.com from their browser
2. Get token from DevTools (F12 → Network → accesstokenrequest → Response → accessToken)
3. Strip "Bearer " prefix if present
4. Write a `commands/run.sh` script that saves the token to all 3 locations (token file, .env, systemd drop-in)
5. Restart bot service
**Prevention**: Token auto-renewal background task should prevent this. If it happens again, check why renewal failed (VPS network? Tradovate API down?)

### Issue 2: "No module named futures_bot.bot"
**Root cause**: Code on VPS is out of sync or has syntax errors.
**Quick fix**:
1. Run `python3 -c "import py_compile; py_compile.compile('FILE', doraise=True)"` on ALL changed files LOCALLY before pushing
2. Write `commands/run.sh` that stops bot, verifies syntax, restarts
3. **Don't do `git reset --hard` inside `run.sh`** - the workflow already handles it
**Prevention**: Always run syntax check locally before pushing code changes.

### Issue 3: IndentationError / SyntaxError after code edit
**Root cause**: Bad edit in Python file.
**Quick fix**: Fix the syntax, verify locally with `py_compile`, push again.
**Prevention**: After every edit to `futures_bot/**`, run:
```python
python3 -c "import py_compile; py_compile.compile('FILEPATH', doraise=True)"
```

### Issue 4: Systemd drop-in has broken quotes
**Root cause**: Values with special chars (like `!` in password) need proper quoting.
**How to identify**: `systemctl show futures-bot --property=Environment` shows garbled values.
**Quick fix**: Rewrite the drop-in file with proper `Environment="KEY=VALUE"` format.
**Prevention**: `_save_token()` now properly updates the drop-in.

### Issue 5: Workflow output not returning (output.txt not updated)
**Root cause**: Usually one of:
- Script inside `run.sh` does `git reset --hard` which overwrites output.txt
- Script too long/slow → SSH timeout
- Deploy workflow and command workflow running simultaneously → push conflict
**Quick fix**: Simplify `run.sh`, remove any `git` commands from it, wait longer (up to 5 min).
**Prevention**: Keep `run.sh` short, never include `git` commands in it.

### Issue 6: Bot crashes repeatedly (restart loop)
**Root cause**: Check `journalctl -u futures-bot -n 50` for the actual error.
**Common causes**:
- Auth failure (see Issue 1)
- Syntax error in code (see Issue 3)
- Missing dependency
- Network issue to Tradovate
**Quick fix**: Read logs via `commands/run.sh`, identify error, fix accordingly.

### Issue 7: Token renewal failed in background
**Root cause**: Tradovate API temporarily unavailable, or token already fully expired.
**How to identify**: Logs show `All token renewal attempts failed` or `Token renewal error`.
**Quick fix**: If token is still somewhat valid, restart bot. If fully expired, need new token from browser (see Issue 1).
**Prevention**: The 3-retry mechanism with backoff should handle temporary failures.

---

## Quick Diagnostic Script Template
Use this minimal script for fast status checks (copy to `commands/run.sh`):
```bash
#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo "Bot: $(systemctl is-active futures-bot)"
python3 -c "
import json,time,base64
d=json.load(open('configs/.tradovate_token.json'))
t=d['access_token'];p=t.split('.')[1];p+='='*(4-len(p)%4)
exp=json.loads(base64.urlsafe_b64decode(p)).get('exp',0)
print(f'Token: {(exp-time.time())/3600:.1f}h')
"
journalctl -u futures-bot --no-pager -n 10 --since "5 min ago" 2>/dev/null | grep -v "^--"
```

---

## Session 2026-03-29 Summary (What Was Fixed)

### Bugs Fixed:
1. `bot.py`: `trade_closed()` was passing `contract_id` instead of symbol name → Now resolves symbol via `get_contract_by_id()`
2. `guardian.py`: Python 3.10+ type hints (`list[]`, `tuple[]`) → Changed to `List[]`, `Tuple[]` from `typing`
3. `news_filter.py`: Same Python 3.10+ type hints fix
4. `requirements.txt`: Added missing `requests>=2.28.0`
5. `vps-command.yml`: Updated hardcoded branch from old `claude/build-cfd-trading-bot-fl0ld` to `claude/fix-bot-functionality-h1Sb3`
6. Added `.gitignore` for `__pycache__/`, `.env`, token files
7. Fixed systemd drop-in `/etc/systemd/system/futures-bot.service.d/env.conf` broken quotes

### Major Improvements:
1. **Token auto-renewal background task** (`start_token_renewal_loop()`) - runs every 4h independently
2. **`_save_token()` now updates systemd drop-in** - tokens persist across service restarts
3. **`_renew_token()` retry logic** - 3 attempts with exponential backoff
4. **`_ensure_token()` more aggressive** - checks every 4h instead of 6h

### Root Cause of Main Failure:
- Tradovate access token expired after ~24h
- VPS IP required CAPTCHA for fresh user/password auth
- Old code didn't renew aggressively enough, and didn't update systemd drop-in
- On service restart, stale token from drop-in was used → expired → fallback to user/pass → CAPTCHA block → "Incorrect password" error

### Final State:
- Bot: **active**, connected to Tradovate
- Account: ELTDER260326211630296397, balance $50,000
- Token: auto-renewing every 4h
- Telegram: @MyPropFirmTrader_bot connected
- All 6 symbols configured: MESM6, MNQM6, MCLM6, MGCM6, MYMM6, M2KM6
- Zero errors in logs
