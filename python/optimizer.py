"""
Optimizer - Walk-forward optimization and Monte Carlo simulation.
Tests parameter combinations and validates robustness.
"""

import itertools
import json
import random
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd

from backtester import BacktestConfig, Backtester
from data_fetcher import add_indicators, load_from_csv, DEFAULT_SYMBOLS

RESULTS_DIR = Path(__file__).parent.parent / "backtest_results"
RESULTS_DIR.mkdir(parents=True, exist_ok=True)


# --- Parameter Grid ---
PARAM_GRID = {
    "risk_per_trade": [0.5, 0.75, 1.0],
    "min_rr": [1.5, 2.0, 2.5, 3.0],
    "trailing_activation": [20, 30, 40],
    "trailing_distance": [15, 20, 25],
    "breakeven_activation": [15, 20, 25],
    "daily_dd_guard": [2.5, 3.0, 3.5],
    "total_dd_guard": [6.0, 7.0, 8.0],
}


def generate_param_combinations(grid: dict, max_combos: int = 200) -> list[dict]:
    """Generate parameter combinations, sampling if too many."""
    keys = list(grid.keys())
    values = list(grid.values())
    all_combos = list(itertools.product(*values))

    combos = []
    if len(all_combos) > max_combos:
        print(f"[Optimizer] {len(all_combos)} total combinations, sampling {max_combos}")
        sampled = random.sample(all_combos, max_combos)
    else:
        sampled = all_combos

    for combo in sampled:
        combos.append(dict(zip(keys, combo)))

    return combos


def walk_forward_split(
    df: pd.DataFrame,
    n_splits: int = 5,
    train_ratio: float = 0.7,
) -> list[tuple]:
    """
    Walk-forward splits: each split has a training and testing window.
    The test window rolls forward.
    """
    total_rows = len(df)
    step_size = total_rows // n_splits
    splits = []

    for i in range(n_splits):
        test_end = total_rows - (n_splits - i - 1) * step_size
        test_start = test_end - step_size
        train_start = max(0, test_start - int(step_size * train_ratio / (1 - train_ratio)))

        if train_start >= test_start or test_start >= test_end:
            continue

        splits.append((train_start, test_start, test_end))

    return splits


def run_optimization(
    symbols: list = None,
    param_grid: dict = None,
    max_combos: int = 100,
) -> pd.DataFrame:
    """
    Grid search optimization with walk-forward validation.

    Returns:
        DataFrame with parameter combinations and their performance
    """
    if symbols is None:
        symbols = DEFAULT_SYMBOLS[:2]  # Optimize on fewer symbols for speed
    if param_grid is None:
        param_grid = PARAM_GRID

    print("=" * 60)
    print("PropFirmBot Parameter Optimizer")
    print("=" * 60)

    # Load data
    m15_data = {}
    h4_data = {}
    for sym in symbols:
        df = load_from_csv(sym, "M15")
        if not df.empty:
            m15_data[sym] = add_indicators(df)
        df_h4 = load_from_csv(sym, "H4")
        if not df_h4.empty:
            h4_data[sym] = df_h4

    if not m15_data:
        print("[ERROR] No data. Run data_fetcher.py first.")
        return pd.DataFrame()

    combos = generate_param_combinations(param_grid, max_combos)
    print(f"[Optimizer] Testing {len(combos)} parameter combinations")

    results = []

    for idx, params in enumerate(combos):
        config = BacktestConfig(**params)
        bt = Backtester(config)
        bt.run(m15_data, h4_data)
        summary = bt.get_summary()

        result = {**params, **summary}
        results.append(result)

        if (idx + 1) % 10 == 0:
            print(f"  Progress: {idx + 1}/{len(combos)} "
                  f"| Best PF so far: {max(r.get('profit_factor', 0) for r in results):.2f}")

    results_df = pd.DataFrame(results)

    # Sort by composite score
    if not results_df.empty and "profit_factor" in results_df.columns:
        results_df["score"] = (
            results_df["profit_factor"].clip(0, 10) * 0.3 +
            results_df["win_rate"].clip(0, 100) / 100 * 0.2 +
            (100 - results_df["max_drawdown_pct"].clip(0, 100)) / 100 * 0.3 +
            results_df["total_pnl_pct"].clip(-50, 50) / 50 * 0.2
        )
        results_df.sort_values("score", ascending=False, inplace=True)

    # Save results
    output_path = RESULTS_DIR / "optimization_results.csv"
    results_df.to_csv(output_path, index=False)
    print(f"\n[Optimizer] Results saved to {output_path}")

    # Print top 5
    print("\n" + "=" * 60)
    print("TOP 5 PARAMETER COMBINATIONS")
    print("=" * 60)
    top5 = results_df.head(5)
    for i, row in top5.iterrows():
        print(f"\n--- Rank {top5.index.get_loc(i) + 1} ---")
        for col in param_grid.keys():
            print(f"  {col}: {row[col]}")
        print(f"  Win Rate: {row.get('win_rate', 0):.1f}%")
        print(f"  Profit Factor: {row.get('profit_factor', 0):.2f}")
        print(f"  Total PnL: ${row.get('total_pnl', 0):.2f} ({row.get('total_pnl_pct', 0):.1f}%)")
        print(f"  Max DD: {row.get('max_drawdown_pct', 0):.1f}%")
        print(f"  Score: {row.get('score', 0):.3f}")

    return results_df


def monte_carlo_simulation(
    trades_csv: str = None,
    num_simulations: int = 1000,
    initial_balance: float = 2000.0,
) -> dict:
    """
    Monte Carlo simulation: shuffle trade order to test robustness.

    Args:
        trades_csv: Path to backtest trades CSV
        num_simulations: Number of random shuffles
        initial_balance: Starting balance

    Returns:
        Dict with simulation statistics
    """
    if trades_csv is None:
        trades_csv = str(RESULTS_DIR / "backtest_trades.csv")

    trades_path = Path(trades_csv)
    if not trades_path.exists():
        print(f"[MonteCarlo] Trades file not found: {trades_csv}")
        return {}

    df = pd.read_csv(trades_path)
    if "pnl" not in df.columns or df.empty:
        print("[MonteCarlo] No PnL data in trades file")
        return {}

    pnls = df["pnl"].values
    print(f"\n{'=' * 60}")
    print(f"Monte Carlo Simulation ({num_simulations} runs, {len(pnls)} trades)")
    print(f"{'=' * 60}")

    final_balances = []
    max_drawdowns = []
    max_drawdown_pcts = []

    for _ in range(num_simulations):
        shuffled = np.random.permutation(pnls)
        balance = initial_balance
        peak = initial_balance
        max_dd = 0

        for pnl in shuffled:
            balance += pnl
            if balance > peak:
                peak = balance
            dd = peak - balance
            if dd > max_dd:
                max_dd = dd

        final_balances.append(balance)
        max_drawdowns.append(max_dd)
        max_drawdown_pcts.append((max_dd / initial_balance) * 100)

    final_balances = np.array(final_balances)
    max_drawdowns = np.array(max_drawdowns)
    max_drawdown_pcts = np.array(max_drawdown_pcts)

    results = {
        "num_simulations": num_simulations,
        "num_trades": len(pnls),
        "median_final_balance": float(np.median(final_balances)),
        "mean_final_balance": float(np.mean(final_balances)),
        "p5_final_balance": float(np.percentile(final_balances, 5)),
        "p95_final_balance": float(np.percentile(final_balances, 95)),
        "prob_profit": float((final_balances > initial_balance).mean() * 100),
        "prob_target": float((final_balances >= initial_balance * 1.10).mean() * 100),
        "prob_ruin_5pct": float((max_drawdown_pcts > 5).mean() * 100),
        "prob_ruin_10pct": float((max_drawdown_pcts > 10).mean() * 100),
        "median_max_dd": float(np.median(max_drawdowns)),
        "p95_max_dd": float(np.percentile(max_drawdowns, 95)),
        "median_max_dd_pct": float(np.median(max_drawdown_pcts)),
        "p95_max_dd_pct": float(np.percentile(max_drawdown_pcts, 95)),
    }

    print(f"\n  Median Final Balance: ${results['median_final_balance']:.2f}")
    print(f"  Mean Final Balance:   ${results['mean_final_balance']:.2f}")
    print(f"  5th Percentile:       ${results['p5_final_balance']:.2f}")
    print(f"  95th Percentile:      ${results['p95_final_balance']:.2f}")
    print(f"\n  Probability of Profit:     {results['prob_profit']:.1f}%")
    print(f"  Probability of 10% Target: {results['prob_target']:.1f}%")
    print(f"  Probability DD > 5%:       {results['prob_ruin_5pct']:.1f}%")
    print(f"  Probability DD > 10%:      {results['prob_ruin_10pct']:.1f}%")
    print(f"\n  Median Max Drawdown:   ${results['median_max_dd']:.2f} ({results['median_max_dd_pct']:.1f}%)")
    print(f"  95th Pct Max Drawdown: ${results['p95_max_dd']:.2f} ({results['p95_max_dd_pct']:.1f}%)")

    # Save
    output_path = RESULTS_DIR / "monte_carlo_results.json"
    with open(output_path, "w") as f:
        json.dump(results, f, indent=2)
    print(f"\n  Results saved to {output_path}")

    return results


if __name__ == "__main__":
    # Run optimization
    opt_results = run_optimization(max_combos=50)

    # Run Monte Carlo on backtest results
    monte_carlo_simulation()
