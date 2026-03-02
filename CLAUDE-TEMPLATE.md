# [PROJECT_NAME] - Project Memory

## MANDATORY RULES (DO NOT SKIP - READ FIRST)

### 1. Language
- **ALWAYS respond in Hebrew (עברית)**
- All communication, explanations, and messages MUST be in Hebrew
- Code comments can be in English

### 2. Server Communication - Push & Listen ONLY
**ALL server/VPS interaction MUST go through GitHub repo only.**
- **NEVER** use direct SSH, SCP, or any direct connection to the VPS
- **NEVER** ask the user to run SSH commands on the server
- **NEVER** suggest connecting to the server directly
- **ONLY** method: edit repo files → git push → GitHub Actions runs on server → results committed back → git pull to read
- This rule applies to ALL operations: checking status, deploying code, fixing issues, monitoring, debugging
- If you need to check something on the server → use a workflow
- If you need to fix something on the server → use a workflow
- If you need to deploy something → use a workflow
- There are NO exceptions to this rule

### 3. User Info
- Name: Noa (נועה)
- Experience: NOT a developer - needs simple, clear, step-by-step instructions
- Local machine: Windows (PowerShell)
- Monitoring tool: RealVNC (for visual checks only)
- Do NOT use technical jargon without explaining it

---

## VPS Details
- Provider: Contabo
- IP: 77.237.234.2
- OS: Ubuntu Linux (NOT Windows)
- VNC: port 5900 (no password)

## Telegram Bot
- Token: 8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g
- Chat ID: 7013213983

---

## Project-Specific Details
<!-- FILL THESE IN FOR EACH PROJECT -->

### Bot Name
[BOT_NAME]

### Account Details
- Platform: [MT5 / Bybit / Binance / etc.]
- Account: [ACCOUNT_NUMBER]
- Server: [SERVER_NAME]
- Type: [Demo / Live / Funded]

### Trading Rules (CRITICAL)
- Max drawdown: [X%]
- Daily drawdown: [X% or NONE]
- Profit target: [X% or NONE]
- Trailing drawdown: [YES/NO]
- [ADD MORE RULES SPECIFIC TO THIS ACCOUNT]

### Risk Settings
- Risk per trade: [X%]
- Max open trades: [X]
- [ADD MORE RISK SETTINGS]

---

## Available GitHub Actions Workflows
<!-- LIST THE WORKFLOWS IN THIS REPO -->
- `workflow-name.yml` - Description of what it does
- `workflow-name.yml` - Description of what it does

## Trigger Files
<!-- FILES THAT TRIGGER WORKFLOWS WHEN PUSHED -->
- `trigger-check.txt` - Triggers status check on VPS
- [ADD MORE TRIGGER FILES]

---

## Project Status
<!-- UPDATE THIS AS WORK PROGRESSES -->

### Completed
- [ ] Item 1
- [ ] Item 2

### In Progress
- [ ] Item 1

### TODO
- [ ] Item 1

---

## File Structure
<!-- DESCRIBE KEY FILES AND FOLDERS -->
- `/src/` - Source code
- `/config/` - Configuration files
- `/.github/workflows/` - GitHub Actions workflows

---

## How to Resume Work
<!-- INSTRUCTIONS FOR CLAUDE TO PICK UP WHERE LEFT OFF -->
- Current state: [DESCRIBE CURRENT STATE]
- Last action: [WHAT WAS DONE LAST]
- Next step: [WHAT NEEDS TO BE DONE NEXT]
- Branch: [CURRENT GIT BRANCH]
- Files on VPS: [PATH TO KEY FILES ON SERVER]

---

## Critical Notes
<!-- ANYTHING IMPORTANT THAT CLAUDE MUST KNOW -->
- Note 1
- Note 2
