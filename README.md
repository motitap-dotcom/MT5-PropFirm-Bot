# TradeDay Futures Bot

Automated micro futures trading bot for TradeDay $50K intraday evaluation, running on Tradovate via Python.

## Overview

- **Platform**: Tradovate API (REST + WebSocket)
- **Prop Firm**: TradeDay ($50K Intraday Evaluation)
- **Contracts**: MES (Micro S&P 500), MNQ (Micro Nasdaq)
- **Strategies**: VWAP Mean Reversion (primary) + Opening Range Breakout (secondary)

## TradeDay Rules

| Rule | Value |
|------|-------|
| Max Drawdown | $2,000 |
| Profit Target | $3,000 |
| Min Trading Days | 5 |
| Consistency | No day > 30% of total profit |
| Position Limit | 5 contracts / 50 micro |
| Intraday Only | Must close all before EOD |

## Architecture

```
GitHub Repo → GitHub Actions → VPS (Ubuntu) → Python Bot → Tradovate API → TradeDay Account
```

## Modules

| Module | Purpose |
|--------|---------|
| `futures_bot/bot.py` | Main entry point |
| `core/tradovate_client.py` | API client |
| `core/guardian.py` | TradeDay rules enforcement |
| `core/risk_manager.py` | Position sizing |
| `core/news_filter.py` | Restricted events |
| `core/notifier.py` | Telegram alerts |
| `strategies/vwap_mean_reversion.py` | VWAP + RSI strategy |
| `strategies/orb_breakout.py` | Opening Range Breakout |

## Setup

1. Set GitHub Secrets (Tradovate, VPS, Telegram credentials)
2. Push code to trigger deploy workflow
3. Bot installs as systemd service on VPS
4. Monitor via Telegram + `status/status.json`

## Disclaimer

Trading futures involves substantial risk of loss. Past performance does not guarantee future results. No algorithm guarantees profits. Always test on simulation before live trading.
