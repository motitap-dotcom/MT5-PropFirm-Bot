# Test Coverage Analysis - PropFirmBot

## Current State: Zero Test Coverage

The codebase currently has **no automated tests** — no test files, no testing frameworks, no CI test stages. All validation happens manually through live trading or ad-hoc backtester runs.

---

## Priority Areas for Testing

### 1. **Python Backtester — Core Trading Logic** (CRITICAL)

The `python/backtester.py` module reimplements the EA's trading logic in Python and is the most testable part of the codebase. It contains pure functions and stateful simulation logic that can be tested without any external dependencies.

**What to test:**

| Function/Method | Why it matters | Example test cases |
|---|---|---|
| `_calculate_lot()` | Wrong position sizing = blown account | Zero SL distance returns 0; risk % correctly applied; lot clamped to [0.01, 5.0] |
| `_get_pip_size()` | Incorrect pip size cascades into wrong SL/TP/PnL | JPY pairs return 0.01; XAUUSD returns 0.01; EURUSD returns 0.0001 |
| `_get_pip_value()` | Affects all PnL calculations | JPY returns 6.7; XAU returns 1.0; majors return 10.0 |
| `_detect_ema_signal()` | False signals = bad trades | Crossover up with bullish H4 bias → BUY; RSI out of range → no signal; NaN indicators → no signal |
| `_is_session_active()` | Trading outside session = unnecessary risk | London hours → True; midnight → False; NY hours → True |
| `_is_weekend_close()` | Holding over weekend when not intended | Friday 20:00 → True; Thursday 20:00 → False |
| `_is_daily_dd_ok()` / `_is_total_dd_ok()` | Drawdown miscalculation = account breach | 2.9% DD with 3% guard → OK; 3.1% DD → not OK; zero balance edge case |
| `_update_open_positions()` | SL/TP/trailing logic errors = lost money | SL hit on BUY closes trade; trailing stop moves correctly; breakeven activates at threshold |
| `_close_all_positions()` | Force close must calculate PnL correctly | BUY position closed at loss; SELL position closed at profit |
| `get_summary()` | Report accuracy affects trading decisions | Empty trades → safe defaults; win rate calculation; Sharpe ratio with zero std dev |
| `_get_h4_bias()` | Wrong bias direction = counter-trend trades | Bullish structure → +1; bearish → -1; insufficient data → 0 |

**Estimated effort:** 2-3 hours. These are all pure Python functions with no I/O dependencies.

---

### 2. **Trade Analyzer — Pattern Detection** (HIGH)

`python/trade_analyzer.py` has well-isolated analysis methods that take DataFrames and return dicts — ideal for unit testing.

**What to test:**

| Method | Test cases |
|---|---|
| `analyze_by_symbol()` | Multiple symbols with mixed PnL; empty DataFrame; missing columns |
| `analyze_by_session()` | Trades in London/NY/Other hours; edge cases at session boundaries |
| `analyze_by_day_of_week()` | Trades spread across weekdays; weekend trades (should be ignored) |
| `analyze_streaks()` | Win-only streak; loss-only streak; alternating wins/losses; empty data |
| `generate_recommendations()` | Symbol with <30% win rate → REMOVE recommendation; >5 consecutive losses → reduce risk |

**Estimated effort:** 1-2 hours.

---

### 3. **Backtester Integration Tests** (HIGH)

End-to-end tests running the `Backtester.run()` method on synthetic market data to verify the full simulation pipeline.

**What to test:**

- A simple uptrend dataset with an EMA crossover produces a BUY trade
- Drawdown guard triggers and prevents new trades
- Weekend close logic fires on Friday evening
- Max positions limit is respected
- Challenge mode stops trading after target is reached
- Trailing stop and breakeven modify SL correctly during the run
- Multiple symbols process independently

**Estimated effort:** 2-3 hours. Requires building synthetic OHLCV DataFrames.

---

### 4. **Configuration Validation** (MEDIUM)

The 6 JSON configs in `configs/` drive the entire EA. Incorrect values can breach prop firm rules.

**What to test:**

- `funded_rules.json`: trailing DD is 6%, daily DD is 0 (Stellar Instant rules)
- `risk_params.json`: risk per trade doesn't exceed safety thresholds
- `symbols.json`: all enabled symbols have valid spread limits
- Cross-config consistency: `challenge_rules.json` and `funded_rules.json` don't conflict
- JSON files are valid JSON and have all required keys

**Estimated effort:** 1 hour.

---

### 5. **MQL5 Logic Parity Tests** (MEDIUM)

The Python backtester mirrors the MQL5 EA logic. Tests should verify that the Python implementations match the MQL5 behavior for key calculations.

**Key areas to cross-validate:**

| Calculation | Python (backtester.py) | MQL5 (EA module) |
|---|---|---|
| Lot sizing | `_calculate_lot()` | `RiskManager::CalculateLotSize()` |
| Daily DD | `_is_daily_dd_ok()` | `Guardian::CalcDailyDD()` |
| Total DD (trailing) | `_is_total_dd_ok()` | `Guardian::CalcTotalDD()` |
| Session check | `_is_session_active()` | `RiskManager::IsSessionActive()` |
| Weekend check | `_is_weekend_close()` | `RiskManager::IsWeekendCloseTime()` |

**Note:** The Python backtester uses simplified versions (e.g., approximate pip values). Tests should document known divergences.

**Estimated effort:** 1-2 hours.

---

### 6. **CI/CD Test Gate** (MEDIUM)

Currently, GitHub Actions workflows deploy code directly to the live VPS with zero validation. A test stage should run before any deployment.

**Proposed workflow change in `.github/workflows/deploy-ea.yml`:**

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install -r python/requirements.txt && pip install pytest
      - run: pytest tests/ -v

  deploy:
    needs: test  # Only deploy if tests pass
    # ... existing deploy steps
```

---

## Recommended Implementation Order

1. **Set up pytest** — Add `pytest` and `pytest-cov` to `requirements.txt`, create `tests/` directory
2. **Backtester unit tests** — Highest value, most testable code, covers critical financial logic
3. **Trade analyzer tests** — Quick to write, validates analysis accuracy
4. **Config validation tests** — Simple but prevents prop firm rule breaches
5. **Integration tests** — End-to-end backtester simulation
6. **CI gate** — Block deployments on test failure

## Dependencies to Add

```
# Add to python/requirements.txt
pytest>=7.0.0
pytest-cov>=4.0.0
```

## Suggested Test Directory Structure

```
tests/
├── __init__.py
├── conftest.py              # Shared fixtures (synthetic market data, configs)
├── test_backtester.py       # Unit tests for Backtester class
├── test_backtester_integration.py  # End-to-end simulation tests
├── test_trade_analyzer.py   # Trade analysis methods
├── test_config_validation.py # Config file correctness
└── test_helpers.py          # Synthetic data generators
```
