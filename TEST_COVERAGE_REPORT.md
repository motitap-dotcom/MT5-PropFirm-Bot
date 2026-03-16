# Test Coverage Analysis Report

**Date:** 2026-03-16
**Status:** Zero automated test coverage

---

## Executive Summary

The codebase has **0 test files, 0 test frameworks installed, and 0 CI test gates**. This is a live trading bot managing real money ($2,000 funded account with 6% trailing drawdown limit). Any untested change risks account breach.

There are **12 MQL5 modules (~6,200 lines)**, **9 Python modules (~2,300 lines)**, **6 JSON configs**, and **4 CI workflows** — all completely untested.

An existing `TEST_COVERAGE_ANALYSIS.md` documents specific test cases. This report focuses on **what to prioritize and why**, with concrete gaps and risk assessment.

---

## Critical Gaps (Immediate Risk to Live Account)

### 1. Drawdown Calculation Divergence — CRITICAL

**The Problem:** Two modules calculate drawdown differently for the same account type.

| Module | Method | Correct for Stellar Instant? |
|--------|--------|------------------------------|
| `Guardian.mqh:248-267` | Trailing DD from equity high water mark | YES |
| `RiskManager.mqh:400-410` | Fixed DD from initial balance | NO |
| `backtester.py:144-148` | Fixed DD from initial balance | NO |

**Risk:** Guardian may halt trading at 5.5% trailing DD, but RiskManager still shows "OK" because fixed DD is only 3%. Or vice versa — RiskManager blocks a safe trade. The backtester produces unreliable results because it underestimates drawdown.

**Needed tests:**
- Unit test: Given equity HWM of $2,100 and current equity of $1,990, trailing DD = 5.24% (not 0.5% from initial $2,000)
- Parity test: Same equity sequence produces same DD in both Guardian and RiskManager logic
- Backtester test: Verify trailing DD tracking matches Guardian formula

### 2. No Config Validation — HIGH

**The Problem:** JSON configs control risk limits, drawdown guards, session times, and position sizing. A single typo (e.g., `"max_total_drawdown_percent": 60` instead of `6`) could blow the account. Nothing validates these configs.

**Needed tests:**
- Schema validation: all required keys exist in all 6 config files
- Rule compliance: `funded_rules.json` matches FundedNext Stellar Instant rules (0% daily DD, 6% trailing total DD, 40% consistency cap)
- Cross-config consistency: DD limits in `risk_params.json` match `funded_rules.json`
- Bounds checking: risk per trade <= 1%, max positions <= 3, lot sizes within safe range

### 3. No CI Test Gate Before Deployment — HIGH

**The Problem:** `deploy-ea.yml` pushes code directly to the live VPS and recompiles the EA with zero pre-flight checks. A broken config or logic error goes straight to production.

**Needed:**
- Add a `test` job to `deploy-ea.yml` that must pass before `deploy` runs
- Run Python tests + config validation on every push to `EA/**` or `configs/**`

---

## High-Priority Gaps (Incorrect Backtest Results)

### 4. Backtester Position Sizing — HIGH

`backtester.py:_calculate_lot()` uses hardcoded pip values (`_get_pip_value()`):
- EURUSD/GBPUSD: 10.0 (approximate)
- USDJPY: 6.7 (varies with USD/JPY rate)
- XAUUSD: 1.0 (varies with gold price)

**Needed tests:**
- Lot calculation with known inputs produces expected results
- Edge cases: zero SL distance, extremely large/small SL
- Clamping to min (0.01) and max (5.0) lot sizes
- Rounding to 0.01 step size

### 5. Backtester Signal Detection — HIGH

`backtester.py:_detect_ema_signal()` implements only exact EMA crossover, while the EA (`SignalEngine.mqh`) has 3 methods: exact cross, recent cross (within N bars), and momentum-based.

**Needed tests:**
- EMA 9 crosses above EMA 21 with bullish H4 bias → BUY signal
- EMA cross but RSI overbought (>70) → no signal (filtered)
- EMA cross but H4 bias opposes → no signal
- NaN/zero values → no signal (no crash)
- Parity: document which EA signal methods the backtester doesn't cover

### 6. Backtester Missing Features — HIGH

The Python backtester completely skips:
- **Spread filtering** (EA's `RiskManager::IsSpreadAcceptable()`)
- **News filtering** (EA's `CNewsFilter::IsSafeToTrade()`)
- **40% consistency rule** (FundedNext requires max 40% of total profit in a single day)

**Needed tests:**
- Integration test: a backtest where >40% of profit comes from one day should flag a warning
- Document spread/news filter gaps as known limitations in test output

---

## Medium-Priority Gaps (Logic Correctness)

### 7. Session Filter Edge Cases — MEDIUM

`backtester.py:_is_session_active()` and `RiskManager.mqh:IsSessionActive()` both filter by UTC hour, but edge cases are untested:
- Exactly at session boundary (e.g., 07:00:00 UTC — is it London or not?)
- Friday close at 20:00 UTC — does it close AT 20:00 or BEFORE?
- DST changes affecting real-world session mapping

**Needed tests:**
- Boundary conditions for London (07:00-11:00) and NY (12:00-16:00)
- Weekend close trigger timing
- Saturday/Sunday → always inactive

### 8. Trade Management (SL/TP/Trailing/Breakeven) — MEDIUM

`backtester.py:_update_open_positions()` handles:
- Stop loss hit
- Take profit hit
- Trailing stop activation (30 pips) and movement (20 pips from high)
- Breakeven activation (20 pips) with offset (2 pips)

**Needed tests:**
- BUY: price drops to SL → closed with correct negative PnL
- BUY: price rises to TP → closed with correct positive PnL
- BUY: price rises 31 pips → trailing SL moves to (high - 20 pips)
- Trailing SL never moves backwards
- Breakeven: price rises 21 pips → SL moves to entry + 2 pips

### 9. Trade Analyzer Accuracy — MEDIUM

`python/trade_analyzer.py` calculates per-symbol, per-session, per-day stats and generates recommendations.

**Needed tests:**
- Symbol with <30% win rate → "REMOVE" recommendation
- Session classification: 09:00 → London, 14:00 → NY, 02:00 → Other
- Streak detection: 5 consecutive losses → max_loss_streak=5
- Empty data → graceful handling (no division by zero)

---

## Low-Priority Gaps (Polish & Completeness)

### 10. Report Formatting — LOW

`python/daily_report.py` generates Telegram HTML messages. Untested but low-risk (cosmetic only).

### 11. Dashboard Server — LOW

`dashboard/server.py` reads `status.json` and journal CSVs. Could benefit from tests for stale data detection and CSV parsing, but failures here don't affect trading.

### 12. Notification Hardcoded Limits — LOW

`Notifications.mqh:264` hardcodes "5% daily / 10% total" instead of "0% daily / 6% trailing". This is a display bug, not a trading logic bug. A test could assert that notification strings match config values.

### 13. Shell Script Validation — LOW

Deployment and diagnostic scripts could be validated for:
- Correct file paths
- Expected commands present
- YAML workflow syntax validity

---

## Recommended Test Implementation Order

| Phase | What | Files to Create | Tests | Impact |
|-------|------|-----------------|-------|--------|
| **1** | Config validation + CI gate | `tests/test_config_validation.py` | ~10 | Prevents catastrophic config errors |
| **2** | Backtester core math | `tests/test_backtester_unit.py` | ~30 | Catches DD divergence, lot sizing errors |
| **3** | Trade analyzer | `tests/test_trade_analyzer.py` | ~15 | Validates analysis accuracy |
| **4** | Backtester integration | `tests/test_backtester_integration.py` | ~10 | End-to-end simulation validation |
| **5** | MQL5 parity docs | `tests/test_mql5_parity.py` | ~8 | Documents known divergences |
| **6** | Reports + dashboard | `tests/test_reports.py` | ~14 | Formatting correctness |

**Total: ~87 tests across 6 files**

---

## Setup Required

```bash
# Install test dependencies
pip install pytest>=7.0.0 pytest-cov>=4.0.0

# Run tests
pytest tests/ -v --cov=python --cov-report=term-missing
```

Add to `python/requirements.txt`:
```
pytest>=7.0.0
pytest-cov>=4.0.0
```

Add test gate to `.github/workflows/deploy-ea.yml`:
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install -r python/requirements.txt
      - run: pytest tests/ -v --cov=python --cov-report=term-missing

  deploy:
    needs: test  # Block deploy on test failure
    # ... existing deploy steps
```

---

## Summary of Findings

| Category | Gap Count | Severity | Effort |
|----------|-----------|----------|--------|
| Drawdown calculation divergence | 1 (affects 3 files) | CRITICAL | 2h |
| Config validation | 0 tests for 6 configs | HIGH | 1h |
| CI test gate | Missing entirely | HIGH | 30min |
| Backtester math (lots, signals) | 0 tests for ~600 lines | HIGH | 3h |
| Session/trade management | 0 tests | MEDIUM | 2h |
| Trade analyzer | 0 tests for ~420 lines | MEDIUM | 2h |
| Reports/dashboard/notifications | 0 tests | LOW | 2h |

**Bottom line:** The highest-ROI action is Phase 1 (config validation + CI gate) — it takes ~1.5 hours and prevents the most catastrophic failures. Phase 2 (backtester math) takes longer but catches the critical DD divergence bug that makes all backtest results unreliable.
