# Test Coverage Analysis - PropFirmBot

## Current State: Zero Test Coverage

The codebase has **no automated tests** — no test files, no testing frameworks, no CI test stages. All validation happens manually through live trading or ad-hoc backtester runs.

This analysis covers **12 MQL5 EA modules** (~3,200 lines), **5 Python modules** (~1,600 lines), **6 JSON config files**, **4 GitHub Actions workflows**, and **1 web dashboard**.

---

## Critical Findings: Bugs & Logic Gaps Found During Review

Before listing what to test, here are real issues found by reading the code — exactly the kind of problems tests would catch:

### Bug 1: Python backtester drawdown calculation doesn't match EA (CRITICAL)
- **EA (`Guardian.mqh:248-267`)**: Uses *trailing* DD from equity high water mark when `m_trailing_dd=true`
- **Python (`backtester.py:144-148`)**: Always uses *fixed* DD from initial balance: `(initial_balance - equity) / initial_balance`
- **Impact**: Backtest results will understate drawdown for the Stellar Instant account, giving false confidence

### Bug 2: Backtester ignores consistency rule (HIGH)
- **Config (`risk_params.json:67-71`)**: Max 40% of total profit in a single day
- **EA**: FundedNext enforces this for payout eligibility
- **Python**: `backtester.py` has no consistency rule check at all
- **Impact**: Backtest may show profitable strategies that would fail payout eligibility

### Bug 3: `RiskManager.IsTotalDrawdownOK()` uses fixed DD, not trailing (HIGH)
- **`RiskManager.mqh:400-410`**: Calculates DD as `(initial_balance - equity) / initial_balance`
- **`Guardian.mqh:248-267`**: Correctly uses equity high water mark when trailing
- **Impact**: The RiskManager may allow trades when the Guardian would block them (or vice versa). Two modules disagree on DD calculation for a Stellar Instant account.

### Bug 4: Backtester pip value approximations are rough (MEDIUM)
- **`backtester.py:115-120`**: `_get_pip_value()` returns hardcoded approximations (10.0 for majors, 6.7 for JPY, 1.0 for XAU)
- **Impact**: Position sizing and PnL calculations in backtests may differ significantly from live trading, especially for XAUUSD where pip value varies with gold price

### Bug 5: Dashboard daily report hardcodes DD limits (LOW)
- **`Notifications.mqh:264`**: Hardcodes `"Daily DD: %.2f%% / 5%%" and "Total DD: %.2f%% / 10%%"` in the Telegram daily report
- **Actual config**: Stellar Instant has 0% daily DD and 6% trailing total DD
- **Impact**: Telegram daily reports show wrong DD limits

---

## Priority 1: Python Backtester Unit Tests (CRITICAL)

The `python/backtester.py` module reimplements the EA's logic in Python. It's the most testable part of the codebase — pure functions and stateful simulation.

### Position Sizing (`_calculate_lot`)
| Test Case | Input | Expected |
|---|---|---|
| Zero SL distance | `sl_distance_pips=0` | Returns 0.0 |
| Normal calculation | Balance=$2000, risk=0.75%, SL=20 pips, EURUSD | `lot = (2000 * 0.0075) / (20 * 10) = 0.075 → 0.07` |
| Clamp to minimum | Very large SL | Returns 0.01 (min lot) |
| Clamp to maximum | Very small SL | Returns 5.0 (max lot) |
| Rounding | Lot=0.075 | Returns 0.07 (floor to 0.01 step) |

### Pip Calculations (`_get_pip_size`, `_get_pip_value`)
| Test Case | Input | Expected |
|---|---|---|
| EURUSD | `_get_pip_size("EURUSD")` | 0.0001 |
| USDJPY | `_get_pip_size("USDJPY")` | 0.01 |
| XAUUSD | `_get_pip_size("XAUUSD")` | 0.01 |
| GBPUSD pip value | `_get_pip_value("GBPUSD")` | 10.0 |

### Signal Detection (`_detect_ema_signal`)
| Test Case | Expected |
|---|---|
| EMA9 crosses above EMA21, RSI=50, H4 bias=+1 | Returns ("BUY", sl_distance, tp_distance) |
| EMA9 crosses below EMA21, RSI=50, H4 bias=-1 | Returns ("SELL", sl_distance, tp_distance) |
| Cross up but RSI=75 (overbought) | Returns (None, 0, 0) |
| Cross up but H4 bias=-1 (counter-trend) | Returns (None, 0, 0) |
| NaN EMA values | Returns (None, 0, 0) |
| Zero ATR | Returns (None, 0, 0) |
| Cross down, RSI=25 (oversold) | Returns (None, 0, 0) |

### Drawdown Guards (`_is_daily_dd_ok`, `_is_total_dd_ok`)
| Test Case | Expected |
|---|---|
| Equity = balance (no loss) | Returns True |
| Daily DD at 2.9%, guard at 3.0% | Returns True |
| Daily DD at 3.1%, guard at 3.0% | Returns False |
| Guard disabled (0%) | Returns True always |
| Zero initial balance | Returns False |
| Equity > initial balance (profit) | Returns True |

### Session Filter (`_is_session_active`)
| Test Case | Expected |
|---|---|
| Monday 09:00 UTC | True (London) |
| Monday 14:00 UTC | True (NY overlap) |
| Monday 03:00 UTC | False (Asian, not configured) |
| Monday 23:00 UTC | False |
| Friday 16:30 UTC | True (NY) |

### Position Management (`_update_open_positions`)
| Test Case | Expected |
|---|---|
| BUY position, price hits SL | Position closed at SL, negative PnL |
| BUY position, price hits TP | Position closed at TP, positive PnL |
| SELL position, price hits SL | Position closed at SL, negative PnL |
| Trailing stop activates at 30 pips profit | SL moves to `close - 20 pips` |
| Breakeven activates at 20 pips profit | SL moves to `entry + 2 pips offset` |
| Trailing SL never moves backwards | New SL > old SL for BUY |

### H4 Bias (`_get_h4_bias`)
| Test Case | Expected |
|---|---|
| Price > EMA50 > EMA200 | Returns +1 (bullish) |
| Price < EMA50 < EMA200 | Returns -1 (bearish) |
| Empty DataFrame | Returns 0 |
| Less than 2 bars | Returns 0 |
| NaN EMA values | Returns 0 |

### Summary Statistics (`get_summary`)
| Test Case | Expected |
|---|---|
| No trades | `{"total_trades": 0}` |
| All wins | `win_rate=100`, positive Sharpe |
| All losses | `win_rate=0`, negative total PnL |
| Zero std dev (identical PnL) | Sharpe ratio = 0 (no division by zero) |
| Mixed wins/losses | Correct profit factor calculation |

**Estimated effort:** 3-4 hours. All pure Python, no mocking needed.

---

## Priority 2: Trade Analyzer Tests (HIGH)

`python/trade_analyzer.py` has well-isolated analysis methods.

### `analyze_by_symbol()`
- Multiple symbols with mixed PnL → correct per-symbol stats
- Symbol with <30% win rate over 5+ trades → "REMOVE" recommendation
- Symbol with >55% win rate and PF>1.5 → "KEEP" recommendation
- Empty DataFrame → empty dict
- Missing PnL column → empty dict

### `analyze_by_session()`
- Trade at 09:00 → counted in London
- Trade at 14:00 → counted in NewYork
- Trade at 02:00 → counted in Other
- Edge case: trade at exactly 12:00 → NewYork (boundary)

### `analyze_by_day_of_week()`
- Trades on all 5 weekdays → 5 entries
- Day with <25% win rate over 3+ trades → recommendation to avoid

### `analyze_streaks()`
- 5 consecutive losses → `max_loss_streak=5`
- Alternating W/L → `max_win_streak=1, max_loss_streak=1`
- Empty data → all zeros

### `generate_recommendations()`
- Integration test: load synthetic trades with known patterns, verify correct recommendations generated

**Estimated effort:** 2 hours.

---

## Priority 3: Configuration Validation Tests (HIGH)

These are cheap to write but prevent catastrophic prop firm rule breaches.

### JSON Validity
- All 6 config files parse as valid JSON
- All required keys exist (schema validation)

### FundedNext Stellar Instant Rule Compliance
```python
def test_funded_rules_stellar_instant():
    rules = json.load(open("configs/funded_rules.json"))
    assert rules["max_daily_drawdown_percent"] == 0       # No daily DD limit
    assert rules["max_total_drawdown_percent"] == 6       # 6% trailing
    assert rules["trailing_drawdown"] == True
    assert rules["ea_allowed"] == True
    assert rules["news_profit_cap_percent"] == 40         # Consistency rule

def test_risk_params_conservative():
    params = json.load(open("configs/risk_params.json"))
    assert params["risk_per_trade_percent"] <= 1.0        # Safety cap
    assert params["max_open_positions"] <= 3              # Position limit
    assert params["drawdown_guards"]["hard_total_dd_percent"] == 6.0
    assert params["drawdown_guards"]["trailing_drawdown"] == True
```

### Cross-Config Consistency
- `risk_params.json` DD limits match `funded_rules.json`
- `account_state.json` phase settings are coherent
- All JSON files reference the same account size ($2000)

**Estimated effort:** 1 hour.

---

## Priority 4: MQL5 Logic Parity Tests (MEDIUM)

The Python backtester should mirror MQL5 EA behavior. These tests document and verify known divergences.

| Calculation | Python (backtester.py) | MQL5 (EA) | Divergence? |
|---|---|---|---|
| Lot sizing | `_calculate_lot()` | `RiskManager::CalculateLotSize()` | Yes — Python uses approximate pip values |
| Daily DD | `_is_daily_dd_ok()` | `Guardian::CalcDailyDD()` | Minor — same formula |
| Total DD (trailing) | `_is_total_dd_ok()` | `Guardian::CalcTotalDD()` | **YES — Python doesn't track equity HWM** |
| Session check | `_is_session_active()` | `RiskManager::IsSessionActive()` | Minor — Python uses local time, EA uses GMT |
| Weekend check | `_is_weekend_close()` | `RiskManager::IsWeekendCloseTime()` | No — same logic |
| EMA signal | `_detect_ema_signal()` | `SignalEngine::GetEMACrossSignal()` | **YES — EA has 3 methods (cross, recent_cross, momentum), Python only has exact cross** |
| Spread filter | Not implemented | `RiskManager::IsSpreadAcceptable()` | **YES — Python backtester skips spread filtering entirely** |
| News filter | Not implemented | `CNewsFilter::IsSafeToTrade()` | **YES — Python backtester has no news filter** |

### Recommended parity tests:
1. Given same inputs, Python lot sizing produces similar (within 10%) result to MQL5 formula
2. Document that Python DD uses fixed baseline vs MQL5 trailing — add TODO to fix
3. Verify that Python EMA crossover detection matches MQL5 "exact cross" path

**Estimated effort:** 2 hours.

---

## Priority 5: Backtester Integration Tests (MEDIUM)

End-to-end tests using synthetic OHLCV data.

### Synthetic Data Scenarios
1. **Clear uptrend**: Steadily rising prices with EMA crossover → should produce BUY trade
2. **Clear downtrend**: Steadily falling prices → should produce SELL trade
3. **Drawdown breach**: Sequence of losses exceeding DD guard → trading should stop
4. **Weekend close**: Trade open on Friday → force-closed at 20:00
5. **Max positions**: Open 2 positions → 3rd trade blocked
6. **Challenge mode**: Equity reaches profit target → all trading stops
7. **Trailing stop**: Price moves 30+ pips in profit → SL moves
8. **Breakeven**: Price moves 20+ pips → SL moves to entry + offset

### Fixtures needed:
```python
@pytest.fixture
def synthetic_uptrend():
    """Generate M15 OHLCV data with clear uptrend and EMA crossover."""
    dates = pd.date_range("2025-01-06 08:00", periods=200, freq="15min")
    prices = np.linspace(1.1000, 1.1200, 200) + np.random.normal(0, 0.0002, 200)
    df = pd.DataFrame({
        "time": dates,
        "open": prices - 0.0002,
        "high": prices + 0.0005,
        "low": prices - 0.0005,
        "close": prices,
        "volume": np.random.randint(100, 1000, 200),
    })
    return add_indicators(df)
```

**Estimated effort:** 3 hours.

---

## Priority 6: Dashboard & Report Tests (LOW)

### `python/daily_report.py`
- `format_telegram_daily()`: Verify HTML formatting with known report dict
- `format_telegram_weekly()`: Same
- `generate_daily_report()` with empty trades → `{"trades": 0}`
- `generate_weekly_report()` with synthetic trades → correct aggregation

### `dashboard/server.py`
- `calculate_stats()`: Pass list of trade dicts → verify win rate, PF, per-symbol breakdown
- `read_status_json()`: Mock file with valid/invalid/missing JSON → verify error handling
- `get_trade_history()`: Parse mock journal CSV → verify open/close matching

**Estimated effort:** 2 hours.

---

## Priority 7: Shell Script & Workflow Validation (LOW)

### Deployment scripts
- `vps-setup/linux/02_deploy_ea.sh`: Verify it copies all 12 EA files (11 .mqh + 1 .mq5)
- `scripts/verify_ea.sh`: Verify it checks for the correct file list

### GitHub Actions workflows
- `.github/workflows/deploy-ea.yml`: Validate YAML syntax
- Verify the deploy workflow has the test job as a prerequisite (once tests exist)

**Estimated effort:** 1 hour.

---

## Recommended Implementation Plan

### Phase 1: Foundation (Day 1)
1. Add `pytest>=7.0.0` and `pytest-cov>=4.0.0` to `python/requirements.txt`
2. Create `tests/` directory with `__init__.py`, `conftest.py`
3. Write shared fixtures (synthetic market data generators, sample config loaders)
4. Create `tests/test_backtester.py` — start with pip size/value and lot calculation

### Phase 2: Core Financial Logic (Day 2)
5. Finish backtester unit tests (signal detection, DD guards, session filters)
6. Write `tests/test_config_validation.py` (config schema + Stellar Instant rules)
7. Add CI test gate to `deploy-ea.yml` (block deployment on test failure)

### Phase 3: Analysis & Integration (Day 3)
8. Write `tests/test_trade_analyzer.py`
9. Write `tests/test_backtester_integration.py` with synthetic scenarios
10. Write parity tests documenting Python vs MQL5 divergences

### Phase 4: Full Coverage (Day 4)
11. Write `tests/test_daily_report.py`
12. Write `tests/test_dashboard_server.py`
13. Add coverage reporting to CI

---

## Suggested Test Structure

```
tests/
├── __init__.py
├── conftest.py                     # Shared fixtures, synthetic data generators
├── test_backtester_unit.py         # Backtester pure function tests (~30 tests)
├── test_backtester_integration.py  # End-to-end simulation tests (~10 tests)
├── test_trade_analyzer.py          # Analysis method tests (~15 tests)
├── test_daily_report.py            # Report formatting tests (~8 tests)
├── test_dashboard_server.py        # Dashboard API tests (~6 tests)
├── test_config_validation.py       # Config correctness tests (~10 tests)
└── test_mql5_parity.py             # Python/MQL5 divergence documentation (~8 tests)
```

**Total: ~87 test cases across 8 test files**

---

## Dependencies to Add

```
# Add to python/requirements.txt
pytest>=7.0.0
pytest-cov>=4.0.0
```

## CI Configuration

```yaml
# Add to .github/workflows/deploy-ea.yml as first job
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install -r python/requirements.txt && pip install pytest pytest-cov
      - run: pytest tests/ -v --cov=python --cov-report=term-missing

  deploy:
    needs: test  # Only deploy if tests pass
    # ... existing deploy steps
```
