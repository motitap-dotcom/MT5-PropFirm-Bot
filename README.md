# PropFirmBot - MT5 CFD Trading Bot for Prop Firm Challenges

Automated Expert Advisor for MetaTrader 5 designed to pass prop firm instant funding challenges ($2,000 account).

## Architecture

```
MT5-PropFirm-Bot/
├── EA/                          # MQL5 Expert Advisor
│   ├── PropFirmBot.mq5          # Main EA (attach to chart)
│   ├── SignalEngine.mqh         # Signal generation (SMC + EMA)
│   ├── RiskManager.mqh          # Risk management module
│   └── TradeManager.mqh         # Trade execution & position mgmt
├── python/                      # Backtesting & optimization
│   ├── data_fetcher.py          # Historical data download from MT5
│   ├── backtester.py            # Strategy backtesting engine
│   ├── optimizer.py             # Parameter optimization + Monte Carlo
│   ├── performance_report.py    # Charts & performance analysis
│   └── requirements.txt
├── configs/
│   ├── challenge_rules.json     # Prop firm challenge parameters
│   ├── risk_params.json         # Risk management configuration
│   └── symbols.json             # Trading symbols setup
├── logs/
└── backtest_results/
```

## Strategies

### Primary: Smart Money Concepts (SMC)
- H4 trend bias (EMA 50/200)
- M15 entry: Liquidity sweep + Order Block / Fair Value Gap reaction
- Minimum 1:2 risk-reward ratio

### Fallback: EMA Crossover
- EMA 9/21 crossover on M15
- RSI 14 filter (avoid overbought/oversold)
- H4 trend confirmation

## Risk Management

| Parameter | Value | Purpose |
|-----------|-------|---------|
| Risk per trade | 0.5-1% | Max $10-20 loss per trade |
| Daily DD guard | 3% | Stop before 5% hard limit |
| Total DD guard | 7% | Stop before 10% hard limit |
| Max positions | 2 | Limit exposure |
| Session filter | London + NY | Trade active hours only |
| Weekend guard | Close Friday 20:00 UTC | No weekend holding |
| Spread filter | 3 pips major / 5 pips XAU | Avoid wide spreads |
| Trailing stop | Activate +30 pips, trail 20 | Lock in profits |
| Breakeven | Move SL to BE at +20 pips | Protect capital |

## Challenge Rules (Stellar Instant $2,000)

- Profit target: 10% ($200)
- Max daily drawdown: 5% ($100)
- Max total drawdown: 10% ($200)
- Minimum 5 trading days
- Leverage: 1:100
- EA allowed: Yes

## Installation

### MT5 EA
1. Copy all files from `EA/` to your MT5 `MQL5/Experts/PropFirmBot/` directory
2. Compile `PropFirmBot.mq5` in MetaEditor
3. Attach to any chart (multi-symbol scanning is built-in)
4. Configure input parameters as needed

### Python Backtesting
```bash
cd python
pip install -r requirements.txt

# Fetch historical data (requires MT5 running on Windows)
python data_fetcher.py

# Run backtest
python backtester.py

# Optimize parameters
python optimizer.py

# Generate performance report
python performance_report.py
```

## Key Safety Features

- **No martingale** - fixed risk per trade
- **No grid trading** - max 1 position per symbol
- **Mandatory SL/TP** on every trade
- **Challenge mode** - auto-stops at profit target
- **Drawdown guards** with safety buffers
- **Min trade duration** - avoids tick scalping flags
- **Magic number** isolation - only manages its own trades

## Disclaimer

Trading financial instruments involves substantial risk of loss. Past performance does not guarantee future results. No algorithm guarantees profits. Always backtest thoroughly and run on demo before live trading. Consult a qualified financial advisor.
