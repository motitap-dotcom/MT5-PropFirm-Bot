"""
Performance Report - Generate visual analysis of backtest results.
Charts: equity curve, drawdown, trade distribution, monthly returns.
"""

import json
from pathlib import Path

import numpy as np
import pandas as pd

try:
    import plotly.graph_objects as go
    from plotly.subplots import make_subplots
    PLOTLY_AVAILABLE = True
except ImportError:
    PLOTLY_AVAILABLE = False

try:
    import matplotlib.pyplot as plt
    import matplotlib.dates as mdates
    MPL_AVAILABLE = True
except ImportError:
    MPL_AVAILABLE = False

RESULTS_DIR = Path(__file__).parent.parent / "backtest_results"


def load_results() -> tuple:
    """Load backtest results from CSV files."""
    trades_path = RESULTS_DIR / "backtest_trades.csv"
    equity_path = RESULTS_DIR / "equity_curve.csv"

    trades_df = pd.DataFrame()
    equity_df = pd.DataFrame()

    if trades_path.exists():
        trades_df = pd.read_csv(trades_path, parse_dates=["entry_time", "exit_time"])
        print(f"[Report] Loaded {len(trades_df)} trades")

    if equity_path.exists():
        equity_df = pd.read_csv(equity_path, parse_dates=["time"])
        print(f"[Report] Loaded {len(equity_df)} equity points")

    return trades_df, equity_df


def calculate_metrics(trades_df: pd.DataFrame, initial_balance: float = 2000.0) -> dict:
    """Calculate comprehensive performance metrics."""
    if trades_df.empty:
        return {}

    pnls = trades_df["pnl"]
    wins = pnls[pnls > 0]
    losses = pnls[pnls <= 0]

    # Consecutive wins/losses
    is_win = (pnls > 0).astype(int)
    max_consec_wins = 0
    max_consec_losses = 0
    current_streak = 0
    current_type = None

    for w in is_win:
        if w == current_type:
            current_streak += 1
        else:
            current_type = w
            current_streak = 1
        if w == 1:
            max_consec_wins = max(max_consec_wins, current_streak)
        else:
            max_consec_losses = max(max_consec_losses, current_streak)

    gross_profit = wins.sum() if len(wins) > 0 else 0
    gross_loss = abs(losses.sum()) if len(losses) > 0 else 0

    # Duration stats
    if "entry_time" in trades_df.columns and "exit_time" in trades_df.columns:
        durations = (trades_df["exit_time"] - trades_df["entry_time"]).dt.total_seconds() / 3600
        avg_duration_hours = durations.mean()
    else:
        avg_duration_hours = 0

    metrics = {
        "Total Trades": len(trades_df),
        "Winning Trades": len(wins),
        "Losing Trades": len(losses),
        "Win Rate (%)": len(wins) / len(trades_df) * 100,
        "": "",  # separator
        "Total P&L ($)": pnls.sum(),
        "Total P&L (%)": (pnls.sum() / initial_balance) * 100,
        "Gross Profit": gross_profit,
        "Gross Loss": gross_loss,
        "Profit Factor": gross_profit / gross_loss if gross_loss > 0 else float("inf"),
        " ": "",  # separator
        "Avg Win ($)": wins.mean() if len(wins) > 0 else 0,
        "Avg Loss ($)": losses.mean() if len(losses) > 0 else 0,
        "Largest Win ($)": wins.max() if len(wins) > 0 else 0,
        "Largest Loss ($)": losses.min() if len(losses) > 0 else 0,
        "  ": "",  # separator
        "Max Consecutive Wins": max_consec_wins,
        "Max Consecutive Losses": max_consec_losses,
        "Avg Trade Duration (hrs)": avg_duration_hours,
        "   ": "",  # separator
        "Sharpe Ratio (ann.)": (pnls.mean() / pnls.std() * np.sqrt(252)) if pnls.std() > 0 else 0,
        "Sortino Ratio (ann.)": (
            pnls.mean() / losses.std() * np.sqrt(252)
            if len(losses) > 0 and losses.std() > 0 else 0
        ),
    }

    return metrics


def print_report(trades_df: pd.DataFrame, initial_balance: float = 2000.0):
    """Print formatted text report to console."""
    metrics = calculate_metrics(trades_df, initial_balance)

    print("\n" + "=" * 60)
    print("       PROPFIRMBOT PERFORMANCE REPORT")
    print("=" * 60)

    for key, val in metrics.items():
        if val == "":
            print("-" * 40)
            continue
        if isinstance(val, float):
            print(f"  {key:30s} : {val:>10.2f}")
        else:
            print(f"  {key:30s} : {val:>10}")

    # Symbol breakdown
    if "symbol" in trades_df.columns:
        print("\n" + "-" * 40)
        print("  BREAKDOWN BY SYMBOL")
        print("-" * 40)
        for sym, group in trades_df.groupby("symbol"):
            sym_wins = group[group["pnl"] > 0]
            wr = len(sym_wins) / len(group) * 100 if len(group) > 0 else 0
            print(f"  {sym:8s}: {len(group):3d} trades | "
                  f"WR: {wr:.1f}% | "
                  f"PnL: ${group['pnl'].sum():.2f}")

    # Exit reason breakdown
    if "exit_reason" in trades_df.columns:
        print("\n" + "-" * 40)
        print("  BREAKDOWN BY EXIT REASON")
        print("-" * 40)
        for reason, group in trades_df.groupby("exit_reason"):
            print(f"  {reason:12s}: {len(group):3d} trades | PnL: ${group['pnl'].sum():.2f}")

    print("\n" + "=" * 60)


def plot_equity_curve_plotly(equity_df: pd.DataFrame, trades_df: pd.DataFrame):
    """Generate interactive equity curve with Plotly."""
    if not PLOTLY_AVAILABLE:
        print("[Report] Plotly not available, skipping interactive charts")
        return

    fig = make_subplots(
        rows=3, cols=1,
        shared_xaxes=True,
        vertical_spacing=0.05,
        row_heights=[0.5, 0.25, 0.25],
        subplot_titles=("Equity Curve", "Drawdown (%)", "Trade P&L Distribution"),
    )

    # Equity curve
    fig.add_trace(
        go.Scatter(
            x=equity_df["time"],
            y=equity_df["equity"],
            name="Equity",
            line=dict(color="blue", width=1),
        ),
        row=1, col=1,
    )
    fig.add_trace(
        go.Scatter(
            x=equity_df["time"],
            y=equity_df["balance"],
            name="Balance",
            line=dict(color="green", width=1, dash="dash"),
        ),
        row=1, col=1,
    )

    # Drawdown
    peak = equity_df["equity"].cummax()
    dd_pct = ((peak - equity_df["equity"]) / peak) * 100
    fig.add_trace(
        go.Scatter(
            x=equity_df["time"],
            y=-dd_pct,
            name="Drawdown %",
            fill="tozeroy",
            line=dict(color="red", width=1),
        ),
        row=2, col=1,
    )

    # Trade PnL distribution
    if not trades_df.empty and "pnl" in trades_df.columns:
        colors = ["green" if p > 0 else "red" for p in trades_df["pnl"]]
        fig.add_trace(
            go.Bar(
                x=list(range(len(trades_df))),
                y=trades_df["pnl"],
                name="Trade PnL",
                marker_color=colors,
            ),
            row=3, col=1,
        )

    fig.update_layout(
        title="PropFirmBot Backtest Results",
        height=900,
        showlegend=True,
    )

    output_path = RESULTS_DIR / "performance_report.html"
    fig.write_html(str(output_path))
    print(f"[Report] Interactive report saved to {output_path}")


def plot_equity_curve_matplotlib(equity_df: pd.DataFrame, trades_df: pd.DataFrame):
    """Generate static equity curve with Matplotlib."""
    if not MPL_AVAILABLE:
        print("[Report] Matplotlib not available, skipping static charts")
        return

    fig, axes = plt.subplots(3, 1, figsize=(14, 10), sharex=False)
    fig.suptitle("PropFirmBot Backtest Results", fontsize=14, fontweight="bold")

    # Equity curve
    ax1 = axes[0]
    ax1.plot(equity_df["time"], equity_df["equity"], label="Equity", color="blue", linewidth=0.8)
    ax1.plot(equity_df["time"], equity_df["balance"], label="Balance", color="green",
             linewidth=0.8, linestyle="--")
    ax1.axhline(y=2000, color="gray", linestyle=":", alpha=0.5)
    ax1.axhline(y=2200, color="gold", linestyle=":", alpha=0.5, label="Target ($2,200)")
    ax1.set_ylabel("Account Value ($)")
    ax1.legend(fontsize=8)
    ax1.grid(True, alpha=0.3)

    # Drawdown
    ax2 = axes[1]
    peak = equity_df["equity"].cummax()
    dd_pct = ((peak - equity_df["equity"]) / peak) * 100
    ax2.fill_between(equity_df["time"], -dd_pct, 0, color="red", alpha=0.3)
    ax2.axhline(y=-5, color="orange", linestyle="--", alpha=0.7, label="Daily DD limit (5%)")
    ax2.axhline(y=-10, color="red", linestyle="--", alpha=0.7, label="Total DD limit (10%)")
    ax2.set_ylabel("Drawdown (%)")
    ax2.legend(fontsize=8)
    ax2.grid(True, alpha=0.3)

    # Trade P&L
    ax3 = axes[2]
    if not trades_df.empty and "pnl" in trades_df.columns:
        colors = ["green" if p > 0 else "red" for p in trades_df["pnl"]]
        ax3.bar(range(len(trades_df)), trades_df["pnl"], color=colors, width=0.8)
        ax3.axhline(y=0, color="black", linewidth=0.5)
        ax3.set_xlabel("Trade #")
        ax3.set_ylabel("P&L ($)")
    ax3.grid(True, alpha=0.3)

    plt.tight_layout()
    output_path = RESULTS_DIR / "performance_report.png"
    plt.savefig(output_path, dpi=150, bbox_inches="tight")
    plt.close()
    print(f"[Report] Static report saved to {output_path}")


def generate_monthly_returns(trades_df: pd.DataFrame, initial_balance: float = 2000.0) -> pd.DataFrame:
    """Calculate monthly return breakdown."""
    if trades_df.empty or "exit_time" not in trades_df.columns:
        return pd.DataFrame()

    trades_df = trades_df.copy()
    trades_df["month"] = trades_df["exit_time"].dt.to_period("M")

    monthly = trades_df.groupby("month").agg(
        trades=("pnl", "count"),
        total_pnl=("pnl", "sum"),
        avg_pnl=("pnl", "mean"),
        win_rate=("pnl", lambda x: (x > 0).mean() * 100),
    ).reset_index()

    monthly["return_pct"] = (monthly["total_pnl"] / initial_balance) * 100

    print("\n" + "=" * 60)
    print("  MONTHLY RETURNS")
    print("=" * 60)
    for _, row in monthly.iterrows():
        bar = "+" * int(abs(row["return_pct"])) if row["return_pct"] > 0 else "-" * int(abs(row["return_pct"]))
        print(f"  {row['month']} | {row['trades']:3.0f} trades | "
              f"PnL: ${row['total_pnl']:>7.2f} ({row['return_pct']:>5.1f}%) | "
              f"WR: {row['win_rate']:.0f}% {bar}")

    return monthly


def generate_full_report():
    """Generate complete performance report."""
    trades_df, equity_df = load_results()

    if trades_df.empty:
        print("[Report] No trade data found. Run backtester.py first.")
        return

    # Text report
    print_report(trades_df)

    # Monthly returns
    generate_monthly_returns(trades_df)

    # Charts
    if not equity_df.empty:
        plot_equity_curve_plotly(equity_df, trades_df)
        plot_equity_curve_matplotlib(equity_df, trades_df)

    print("\n[Report] Full report generated successfully!")


if __name__ == "__main__":
    generate_full_report()
