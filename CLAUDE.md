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

### 6. Scripts with `systemctl restart` don't return VPS output.
- NEVER include `systemctl restart/stop/start` inside `commands/run.sh` - it causes the SSH session to not push output back.
- For restarts: use `scripts/fix_and_restart.sh` (triggers `vps-fix.yml`), NOT `commands/run.sh`.
- For status checks: use `commands/run.sh` with read-only commands only.
- **Separate restart and status check into two different pushes.**

### 7. Preserve token and .env during git reset.
- ALL workflows do `git reset --hard` which DELETES untracked/modified files.
- Token file (`configs/.tradovate_token.json`) and `.env` MUST be backed up before and restored after `git reset --hard`.
- Pattern: `cp configs/.tradovate_token.json /tmp/.tradovate_token_backup.json` → `git reset --hard` → `cp /tmp/.tradovate_token_backup.json configs/.tradovate_token.json`

### 8. Don't push too fast — avoid workflow race conditions.
- Wait for one workflow to finish before pushing the next change.
- `auto-merge-deploy.yml` and `vps-command.yml` can trigger simultaneously on the same push → they fight over VPS git state.
- `auto-merge-deploy.yml` has `paths-ignore: commands/**` so pushing ONLY `commands/run.sh` won't trigger it.
- If you change code files + `commands/run.sh` in the same push, both workflows trigger and race.

### 9. CRITICAL: Don't break market data (learned the hard way on 2026-04-23).
- **Market data path MUST be WebSocket.** The REST `/md/getChart` endpoint returns `OperationNotSupported mode: None` on this account. `get_historical_bars` in `futures_bot/core/tradovate_client.py` MUST use WebSocket (`md/getChart` via the MD WS after authorize). If you see REST bars code, you are regressing — stop.
- **The MD WS `authorize` body is JSON:** `f"authorize\n1\n\n{json.dumps({'token': token})}"`. NOT raw token. The server replies `{"s":401,"d":"Access is denied"}` for bad format.
- **`mdAccessToken` is required for MD WS.** Playwright browser auth only captures `accessToken`. After browser auth you MUST call `_renew_token_safe()` once — the `/auth/renewaccesstoken` response contains both `accessToken` AND `mdAccessToken`. Without this, MD WS returns 401.
- **Bar volume is `upVolume + downVolume` (+ bid/offerVolume), NOT `volume`.** Tradovate chart frames don't have a `volume` key. `_to_bar` in `bot.py` MUST sum these, else VWAP=0 forever.
- **Systemd ExecStart is `/usr/local/sbin/futures-bot-wrapper.sh`, NOT `python3 -m futures_bot.bot` directly.** The wrapper chooses between `/root/MT5-PropFirm-Bot` (repo copy) and `/opt/futures_bot_stable` (stable fallback). If you rewrite the service file to call python directly, the bot will fail with `No module named futures_bot.bot` and loop.
- **`/opt/futures_bot_stable/` is the intentional stable copy** used when `git reset --hard` wipes `/root/MT5-PropFirm-Bot/`. `scripts/fix_and_restart.sh` MUST `rsync` `/root/MT5-PropFirm-Bot/futures_bot/` to `/opt/futures_bot_stable/futures_bot/` on every run. Don't delete /opt.
- **Newer `websockets` library removed `.open`.** Use the `_ws_closed(ws)` helper in `tradovate_client.py` (checks `.closed` or `.state`).

---

## Architecture: How This Bot Works

```
[Repo on GitHub]
      |
      | (push to claude/** triggers auto-merge → main)
      v
[GitHub Actions runner]
      |
      | (SSH into VPS via appleboy/ssh-action + password)
      v
[Contabo VPS - Ubuntu]
      |
      | (Python bot connects to Tradovate API)
      v
[Tradovate API → TradeDay account]
      |
      | (Bot writes status.json, logs)
      v
[Results committed back to repo by VPS git push]
```

Claude edits files locally -> pushes to `claude/**` branch -> auto-merge-deploy merges to `main` + deploys -> VPS runs bot -> VPS pushes output back to repo.

---

## GitHub Actions Workflows (6 pipelines)

### 1. `auto-merge-deploy.yml` — Auto-merge + Deploy (NEW - from Tradovate-Bot)
- **Trigger**: push to `claude/**` branches (except `commands/**`, `*.md`, status files)
- **What it does**: Syntax check → merge to `main` → SSH deploy to VPS → restart bot
- **Key features**: Auto conflict resolution, token preservation, PYTHONPATH in service
- **Use for**: All code/config changes

### 2. `vps-command.yml` — Run any command on VPS
- **Trigger**: push that changes `commands/run.sh`
- **What it does**: Executes `commands/run.sh` on VPS, VPS pushes output back
- **Output file**: `commands/output.txt`
- **IMPORTANT**: VPS needs `GH_TOKEN` (github.token) to push output back. Token is passed via `envs` and set as git remote URL.
- **Use for**: Status checks, reading logs, diagnostics. **NO restarts in this script!**

### 3. `deploy-bot.yml` — Deploy on push to main
- **Trigger**: push to `main` that changes `futures_bot/**`, `configs/**`, or `requirements.txt`
- **What it does**: Syntax check → deploy → fix service file → restart
- **Includes**: Token preservation, PYTHONPATH, Playwright install

### 4. `vps-check.yml` — Run VPS diagnostics
- **Trigger**: push that changes `trigger-check.txt` or `scripts/check_bot.sh`
- **Output file**: `vps_report.txt`

### 5. `vps-fix.yml` — Fix and restart bot
- **Trigger**: push that changes `scripts/fix_and_restart.sh` or `scripts/install_bot.sh`
- **Output file**: `vps_fix_report.txt`
- **Use for**: Restarts! This is the correct way to restart the bot.

### 6. `server-manage.yml` — Manual server management (NEW)
- **Trigger**: manual `workflow_dispatch` in GitHub Actions UI
- **Commands**: status, restart-bot, bot-logs, check-trades, fix-bot, full-diagnostic
- **Output**: `server_manage_result.json`

All workflows: preserve token, include PYTHONPATH, send Telegram notifications.

---

## Tradovate Auth — CRITICAL KNOWLEDGE

### Auth Method (web-style, no API key needed)
1. Password is **encrypted**: rearrange by offset + reverse + base64 encode
2. **HMAC** is computed and placed in the `sec` field (NOT `hmac` field!)
3. Payload includes `chl: ""` (empty string, but must be present)
4. `organization: ""` (empty for TradeDay — NOT "TradeDay"!)
5. `cid: 8`, `appId: "tradovate_trader(web)"`

### CAPTCHA Bypass — Playwright Browser Auth
- First login from new IP requires CAPTCHA (`p-captcha: true`)
- Bot has `_try_browser_auth()` in `tradovate_client.py` that launches headless Chromium
- Fills username/password on `trader.tradovate.com/welcome` and captures token from network response
- Selectors: `input[type="text"]` for username, `input[type="password"]` for password, `button:has-text("Log")` for submit
- **Requires**: `playwright` pip package + Chromium installed (`python3 -m playwright install chromium`)
- **Tradovate-Bot's venv** at `/root/tradovate-bot/venv/bin/python3` already has Playwright installed

### Token Lifecycle
1. Playwright captures token → saved to `configs/.tradovate_token.json`
2. Token valid for ~2 hours
3. Bot renews automatically via `/auth/renewaccesstoken` every 4 hours
4. Token file must survive `git reset --hard` (see Iron Rule #7)

### Auth Fallback Chain (in `connect()`)
1. Load saved token from file → verify with `/account/list`
2. If invalid → try renew
3. Load env token (`TRADOVATE_ACCESS_TOKEN`) → verify
4. If invalid → try renew
5. Full user/password auth (encrypted + HMAC)
6. If CAPTCHA → Playwright browser auth (automatic!)

### Common Auth Errors
| Error | Cause | Fix |
|---|---|---|
| `CAPTCHA required` | First login from IP | Playwright handles automatically |
| `Incorrect username or password` | Wrong encryption, wrong `organization`, or `hmac` instead of `sec` | Check `_authenticate()` payload |
| `Expired Access Token` | Token expired, renewal failed | Playwright will get fresh token |
| Token renewal loop | `_ensure_token()` threshold too aggressive | Check `remaining < 7200` logic |

---

## VPS Service File — MUST HAVE PYTHONPATH

The systemd service file **MUST** include `Environment=PYTHONPATH=/root/MT5-PropFirm-Bot`:

```ini
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=/usr/bin/python3 -m futures_bot.bot
Restart=on-failure
RestartSec=60
Environment=PYTHONUNBUFFERED=1
Environment=PYTHONPATH=/root/MT5-PropFirm-Bot
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
```

Without PYTHONPATH: `No module named futures_bot.bot`
Without EnvironmentFile: No Tradovate credentials

---

## Commands Noa Can Ask For

| Request from Noa | What Claude does | Trigger file | Output file |
|---|---|---|---|
| "מה המצב של הבוט?" | Writes status script to `commands/run.sh`, pushes | `commands/run.sh` | `commands/output.txt` |
| "תראה לי לוגים" | Writes log-reading script to `commands/run.sh`, pushes | `commands/run.sh` | `commands/output.txt` |
| "יש טרייד פתוח?" | Writes position-check script to `commands/run.sh`, pushes | `commands/run.sh` | `commands/output.txt` |
| "תתקן את הבוט" | Edits `scripts/fix_and_restart.sh`, pushes | `scripts/fix_and_restart.sh` | `vps_fix_report.txt` |
| "תעדכן את הקוד" | Edits files in `futures_bot/` or `configs/`, pushes | `futures_bot/**` or `configs/**` | auto-merge deploys |
| "תעשה בדיקה מלאה" | Edits `trigger-check.txt`, pushes | `trigger-check.txt` | `vps_report.txt` |

### Workflow for every request (MUST FOLLOW):
1. Write/edit the trigger file
2. Push to GitHub (to branch: `claude/build-cfd-trading-bot-fl0ld`)
3. Wait ~180-240 seconds for Actions to run and push output back
4. `git fetch origin claude/build-cfd-trading-bot-fl0ld` + check if output commit exists
5. `git checkout origin/claude/build-cfd-trading-bot-fl0ld -- commands/output.txt`
6. Read output and present results to Noa WITH timestamp
7. If `git pull` conflict (VPS pushed while we pushed): `git pull --rebase` then retry
8. **NEVER ask Noa to check GitHub Actions manually**

### Output retrieval pattern (copy-paste this):
```bash
BEFORE=$(git log origin/claude/build-cfd-trading-bot-fl0ld -1 --format=%H -- commands/output.txt)
sleep 180
git fetch origin claude/build-cfd-trading-bot-fl0ld
AFTER=$(git log origin/claude/build-cfd-trading-bot-fl0ld -1 --format=%H -- commands/output.txt)
if [ "$BEFORE" != "$AFTER" ]; then
  git checkout origin/claude/build-cfd-trading-bot-fl0ld -- commands/output.txt
  cat commands/output.txt
fi
```

---

## File Map — Real paths

### In this repo (local):

| Path | Purpose |
|---|---|
| `futures_bot/bot.py` | Main bot entry point |
| `futures_bot/core/tradovate_client.py` | Tradovate REST + WebSocket API client + Playwright auth |
| `futures_bot/core/guardian.py` | MASTER WATCHDOG - 5 safety layers |
| `futures_bot/core/risk_manager.py` | Position sizing, session filter, contract specs |
| `futures_bot/core/news_filter.py` | Restricted events filter |
| `futures_bot/core/notifier.py` | Telegram notifications |
| `futures_bot/core/status_writer.py` | Writes status.json for monitoring |
| `futures_bot/strategies/vwap_mean_reversion.py` | Primary: VWAP + RSI mean reversion |
| `futures_bot/strategies/orb_breakout.py` | Secondary: Opening Range Breakout |
| `configs/bot_config.json` | Main bot configuration |
| `configs/restricted_events.json` | Restricted news events calendar |
| `configs/.tradovate_token.json` | Saved auth token (in .gitignore!) |
| `commands/run.sh` | Script to execute on VPS (trigger for vps-command) |
| `commands/output.txt` | Output from last VPS command |
| `commands/check_status.sh` | Reusable status check script |
| `scripts/check_bot.sh` | Bot diagnostic script |
| `scripts/fix_and_restart.sh` | Fix + restart script |
| `scripts/install_bot.sh` | Install bot as systemd service |
| `server_cron.sh` | Auto-heal cron (every 5 min) |
| `.github/workflows/auto-merge-deploy.yml` | Auto-merge claude/** → main + deploy |
| `.github/workflows/deploy-bot.yml` | Deploy on push to main |
| `.github/workflows/vps-command.yml` | Run commands on VPS |
| `.github/workflows/vps-check.yml` | VPS diagnostics |
| `.github/workflows/vps-fix.yml` | Fix and restart |
| `.github/workflows/server-manage.yml` | Manual server management |
| `trigger-check.txt` | Edit to trigger vps-check workflow |
| `requirements.txt` | Python dependencies (includes playwright) |
| `.gitignore` | Ignores __pycache__, .env, .tradovate_token.json |

### On VPS:

| Path | Purpose |
|---|---|
| `/root/MT5-PropFirm-Bot/` | This repo (clone) |
| `/root/MT5-PropFirm-Bot/.env` | Environment secrets |
| `/root/MT5-PropFirm-Bot/configs/.tradovate_token.json` | Auth token (NOT in git!) |
| `/root/MT5-PropFirm-Bot/logs/bot.log` | Bot log |
| `/root/MT5-PropFirm-Bot/status/status.json` | Status snapshot |
| `/root/tradovate-bot/` | Working Tradovate-Bot (FundedNext) - reference code |
| `/root/tradovate-bot/venv/bin/python3` | Python with Playwright installed |
| `/etc/systemd/system/futures-bot.service` | Systemd service file |

---

## Account Details

- Prop firm: TradeDay
- Account type: $50K Intraday Evaluation
- Account ID: ELTDER260326211630296397
- Tradovate account ID: 45373493
- Platform: Tradovate (DEMO)
- Tradovate username: `TD_Motitap` (stored in `TRADOVATE_USER` secret)

### TradeDay $50K Intraday Rules (CRITICAL)
- **Max Drawdown**: $2,000 (balance cannot drop below $48,000)
- **Profit Target**: $3,000
- **Min Trading Days**: 5
- **Consistency Rule**: No single day > 30% of total profit (max ~$900/day)
- **Position Limit**: 5 contracts / 50 micro contracts
- **Intraday Only**: ALL positions must be closed before end of day
- **Restricted Events**: Must flatten before certain news events
- Automated trading: ALLOWED
- No time limit to pass

---

## Other Bot on Same VPS

There is another working bot at `/root/tradovate-bot/` (repo: `motitap-dotcom/Tradovate-Bot`):
- Account: FundedNext (`FNFTMOTITAPWnBks`)
- Service: `tradovate-bot.service`
- Has Playwright + venv fully installed
- Our workflows were built based on patterns from this bot

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

## GitHub Secrets Needed
- `VPS_HOST`, `VPS_USER`, `VPS_PASSWORD` — VPS access
- `TRADOVATE_USER`, `TRADOVATE_PASS` — Tradovate login
- `TELEGRAM_TOKEN`, `TELEGRAM_CHAT_ID` — Telegram notifications
- `TRADOVATE_ACCESS_TOKEN` — (optional, can be empty - Playwright handles CAPTCHA)

---

## Bot Architecture (Python)

| Module | File | Role |
|---|---|---|
| Main Bot | `futures_bot/bot.py` | Entry point, main loop, strategy coordination |
| Tradovate Client | `core/tradovate_client.py` | REST + WebSocket API + Playwright auth |
| Guardian | `core/guardian.py` | MASTER WATCHDOG - 5 states, enforces ALL rules |
| Risk Manager | `core/risk_manager.py` | Position sizing, session times, contract specs |
| News Filter | `core/news_filter.py` | Blocks trading around restricted events |
| Notifier | `core/notifier.py` | Telegram alerts |
| Status Writer | `core/status_writer.py` | Writes status.json |
| VWAP Strategy | `strategies/vwap_mean_reversion.py` | Primary: VWAP + RSI mean reversion |
| ORB Strategy | `strategies/orb_breakout.py` | Secondary: Opening Range Breakout |

---

## Troubleshooting Guide

### Bot not starting
1. Check `systemctl status futures-bot` — what's the error?
2. `No module named futures_bot.bot` → Missing `PYTHONPATH` in service file
3. `CAPTCHA required` → Playwright should handle. If not, check Playwright is installed
4. `Incorrect username or password` → Check: `organization` must be `""`, HMAC must go in `sec` field, password must be encrypted

### Bot starts but doesn't trade
1. Check trading hours: 9:30-15:30 ET (13:30-19:30 UTC in EDT, 14:30-20:30 UTC in EST)
2. Check `configs/bot_config.json` exists on VPS (may be deleted by `git reset --hard`)
3. Check `status/` directory exists on VPS
4. Check market data: Tradovate WebSocket may not deliver data for micro contracts
5. Check `configs/restricted_events.json` exists

### Token issues
1. Token expires → bot auto-renews (every 4 hours or when < 2 hours left)
2. Token renewal loop → check `_ensure_token()` thresholds
3. Token lost after deploy → all workflows should backup/restore (Iron Rule #7)
4. CAPTCHA on every restart → Playwright handles. Token should be saved and survive restarts.

### Workflow output not returning
1. Script has `systemctl restart` → output won't come back (Iron Rule #6)
2. Two workflows racing → wait for first to finish (Iron Rule #8)
3. `git push` from VPS fails → check `GH_TOKEN` is passed and git remote is set

### Deploy issues
1. Code not on VPS → check if auto-merge to main happened (`git log origin/main`)
2. Config missing after deploy → `git reset --hard` deleted it; need to ensure it's committed in repo
3. Service file wrong → check deploy workflow writes correct service file with PYTHONPATH

---

## How to Resume Work
1. Don't assume anything from previous sessions
2. Push a read-only status check to `commands/run.sh`:
   ```bash
   #!/bin/bash
   cd /root/MT5-PropFirm-Bot
   echo "=== Status $(date -u '+%Y-%m-%d %H:%M UTC') ==="
   echo "Service: $(systemctl is-active futures-bot)"
   echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
   tail -20 logs/bot.log
   ```
3. Wait 180s, fetch output, read results
4. Check `status/status.json` for last bot-written snapshot
5. All output files have timestamps - always verify freshness
