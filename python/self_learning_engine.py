"""
PropFirmBot - Self-Learning Engine
====================================
Continuous automated trade analysis system that learns from every trade
and generates parameter adjustment recommendations.

Analyzes these dimensions independently:
1. Per-Symbol performance (EURUSD, GBPUSD, USDJPY, XAUUSD)
2. Per-Session (London, New York, Overlap)
3. Per-Day-of-Week (Monday-Friday)
4. Per-Strategy (SMC vs EMA)
5. Per-Signal-Type (CrossOver, RecentCross, Momentum, OrderBlock, FVG, LiqSweep)
6. Risk/Reward realized vs planned
7. Drawdown patterns and recovery
8. Trade duration optimization
9. Consecutive loss patterns
10. Consistency rule compliance

Run periodically (daily/weekly) to evolve trading parameters.
"""

import json
import os
from datetime import datetime, timedelta
from pathlib import Path
from collections import defaultdict
from dataclasses import dataclass, field, asdict
from typing import Dict, List, Optional

import numpy as np
import pandas as pd


# --- Data Classes ---

@dataclass
class ParameterScore:
    """Score for a single parameter dimension."""
    name: str
    value: str
    trades: int = 0
    wins: int = 0
    losses: int = 0
    breakevens: int = 0
    total_pnl: float = 0.0
    avg_pnl: float = 0.0
    win_rate: float = 0.0
    profit_factor: float = 0.0
    avg_win: float = 0.0
    avg_loss: float = 0.0
    max_win: float = 0.0
    max_loss: float = 0.0
    max_consec_losses: int = 0
    avg_duration_min: float = 0.0
    avg_rr_realized: float = 0.0
    score: float = 50.0  # 0-100 composite score
    trend: str = "stable"  # improving, declining, stable
    recommendation: str = ""


@dataclass
class LearningState:
    """Persistent state for tracking learning progress."""
    last_analysis: str = ""
    total_analyses: int = 0
    parameter_history: Dict[str, List[dict]] = field(default_factory=dict)
    active_adjustments: List[dict] = field(default_factory=list)
    improvement_log: List[dict] = field(default_factory=list)


class SelfLearningEngine:
    """
    Core self-learning system. Analyzes trade history across multiple
    dimensions and generates specific, actionable parameter adjustments.
    """

    def __init__(self, journal_dir=None, config_dir=None, state_file=None):
        base = Path(__file__).parent.parent
        self.journal_dir = Path(journal_dir) if journal_dir else base / "backtest_results"
        self.config_dir = Path(config_dir) if config_dir else base / "configs"
        self.state_file = Path(state_file) if state_file else base / "learning_state.json"
        self.trades = pd.DataFrame()
        self.configs = {}
        self.state = LearningState()
        self._load_state()

    # --- Data Loading ---

    def load_trades(self, csv_path=None):
        """Load trades from journal CSV files."""
        frames = []
        search_dir = Path(csv_path) if csv_path else self.journal_dir

        if search_dir.is_file():
            frames.append(pd.read_csv(search_dir))
        else:
            for f in sorted(search_dir.glob("**/PropFirmBot_Journal*.csv")):
                try:
                    df = pd.read_csv(f)
                    frames.append(df)
                except Exception:
                    pass

        if frames:
            self.trades = pd.concat(frames, ignore_index=True)
            if "DateTime" in self.trades.columns:
                self.trades["DateTime"] = pd.to_datetime(
                    self.trades["DateTime"], errors="coerce"
                )
            if "PnL" in self.trades.columns:
                self.trades["PnL"] = pd.to_numeric(
                    self.trades["PnL"], errors="coerce"
                )
        return len(self.trades)

    def load_trades_from_dataframe(self, df: pd.DataFrame):
        """Load trades directly from a DataFrame (for testing)."""
        self.trades = df.copy()
        return len(self.trades)

    def load_configs(self):
        """Load current EA configs."""
        for name in ["risk_params", "symbols", "funded_rules", "account_state"]:
            path = self.config_dir / f"{name}.json"
            if path.exists():
                with open(path) as f:
                    self.configs[name] = json.load(f)

    # --- Core Analysis ---

    def analyze_dimension(self, group_col: str, group_name: str) -> Dict[str, ParameterScore]:
        """Analyze a single dimension (symbol, session, day, etc.)."""
        if self.trades.empty or "PnL" not in self.trades.columns:
            return {}

        if group_col not in self.trades.columns:
            return {}

        results = {}
        for value, group in self.trades.groupby(group_col):
            if pd.isna(value):
                continue
            pnl = group["PnL"].dropna()
            if len(pnl) == 0:
                continue

            score = ParameterScore(name=group_name, value=str(value))
            score.trades = len(pnl)
            score.wins = int((pnl > 0).sum())
            score.losses = int((pnl < 0).sum())
            score.breakevens = int((pnl == 0).sum())
            score.total_pnl = round(float(pnl.sum()), 2)
            score.avg_pnl = round(float(pnl.mean()), 2)
            score.win_rate = round(score.wins / score.trades * 100, 1) if score.trades > 0 else 0
            score.max_win = round(float(pnl.max()), 2) if len(pnl) > 0 else 0
            score.max_loss = round(float(pnl.min()), 2) if len(pnl) > 0 else 0

            wins_total = float(pnl[pnl > 0].sum())
            losses_total = abs(float(pnl[pnl < 0].sum()))
            score.profit_factor = round(wins_total / losses_total, 2) if losses_total > 0 else (
                999.0 if wins_total > 0 else 0
            )
            score.avg_win = round(float(pnl[pnl > 0].mean()), 2) if score.wins > 0 else 0
            score.avg_loss = round(float(pnl[pnl < 0].mean()), 2) if score.losses > 0 else 0

            # Duration
            if "Duration" in group.columns:
                dur = pd.to_numeric(group["Duration"], errors="coerce").dropna()
                score.avg_duration_min = round(float(dur.mean()), 1) if len(dur) > 0 else 0

            # R:R realized
            if "RR" in group.columns:
                rr = pd.to_numeric(group["RR"], errors="coerce").dropna()
                score.avg_rr_realized = round(float(rr.mean()), 2) if len(rr) > 0 else 0

            # Consecutive losses
            score.max_consec_losses = self._max_consec_losses(pnl.values)

            # Composite score (0-100)
            score.score = self._compute_score(score)

            # Trend detection
            score.trend = self._detect_trend(group_name, str(value), score.score)

            # Recommendation
            score.recommendation = self._generate_recommendation(score)

            results[str(value)] = score

        return results

    def _max_consec_losses(self, pnl_array) -> int:
        """Calculate max consecutive losses."""
        max_streak = 0
        current = 0
        for p in pnl_array:
            if p < 0:
                current += 1
                max_streak = max(max_streak, current)
            else:
                current = 0
        return max_streak

    def _compute_score(self, s: ParameterScore) -> float:
        """Compute composite 0-100 score."""
        if s.trades < 3:
            return 50.0  # Insufficient data

        score = 50.0

        # Win rate contribution (0-30 points)
        if s.win_rate >= 60:
            score += 30
        elif s.win_rate >= 50:
            score += 20
        elif s.win_rate >= 40:
            score += 10
        elif s.win_rate < 30:
            score -= 20

        # Profit factor contribution (0-30 points)
        if s.profit_factor >= 2.0:
            score += 30
        elif s.profit_factor >= 1.5:
            score += 20
        elif s.profit_factor >= 1.0:
            score += 10
        elif s.profit_factor < 0.8:
            score -= 20

        # Risk/reward (0-20 points)
        if s.avg_win > 0 and s.avg_loss != 0:
            rr = abs(s.avg_win / s.avg_loss)
            if rr >= 2.5:
                score += 20
            elif rr >= 2.0:
                score += 15
            elif rr >= 1.5:
                score += 10
            elif rr < 1.0:
                score -= 10

        # Consecutive losses penalty (-20 to 0)
        if s.max_consec_losses >= 5:
            score -= 20
        elif s.max_consec_losses >= 3:
            score -= 10

        # PnL direction
        if s.total_pnl > 0:
            score += 10
        elif s.total_pnl < -50:
            score -= 10

        return max(0, min(100, round(score, 1)))

    def _detect_trend(self, dimension: str, value: str, current_score: float) -> str:
        """Detect if performance is improving or declining."""
        key = f"{dimension}:{value}"
        history = self.state.parameter_history.get(key, [])

        if len(history) < 2:
            return "stable"

        recent_scores = [h.get("score", 50) for h in history[-5:]]
        if len(recent_scores) < 2:
            return "stable"

        avg_old = np.mean(recent_scores[:len(recent_scores)//2])
        avg_new = np.mean(recent_scores[len(recent_scores)//2:])

        if avg_new > avg_old + 5:
            return "improving"
        elif avg_new < avg_old - 5:
            return "declining"
        return "stable"

    def _generate_recommendation(self, s: ParameterScore) -> str:
        """Generate actionable recommendation."""
        if s.trades < 5:
            return "MONITOR - Insufficient data (< 5 trades)"

        if s.score >= 80:
            return "KEEP - Excellent performance"
        elif s.score >= 65:
            return "KEEP - Good performance"
        elif s.score >= 50:
            if s.trend == "declining":
                return "REDUCE RISK - Declining performance"
            return "MONITOR - Average, watch closely"
        elif s.score >= 35:
            if s.trend == "improving":
                return "MONITOR - Below average but improving"
            return "REDUCE RISK - Poor performance"
        else:
            return "REMOVE - Very poor performance"

    # --- Multi-Dimension Analysis ---

    def _add_session_column(self):
        """Add session column based on trade hour."""
        if "DateTime" not in self.trades.columns:
            return
        hours = self.trades["DateTime"].dt.hour
        conditions = [
            (hours >= 7) & (hours < 11),
            (hours >= 12) & (hours < 16),
        ]
        choices = ["London", "NewYork"]
        self.trades["Session"] = np.select(conditions, choices, default="Other")

    def _add_day_column(self):
        """Add day of week column."""
        if "DateTime" not in self.trades.columns:
            return
        day_names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        self.trades["DayOfWeek"] = self.trades["DateTime"].dt.weekday.map(
            lambda x: day_names[x] if x < len(day_names) else "Unknown"
        )

    def _add_hour_column(self):
        """Add hour column."""
        if "DateTime" not in self.trades.columns:
            return
        self.trades["Hour"] = self.trades["DateTime"].dt.hour

    def run_full_analysis(self) -> dict:
        """Run complete multi-dimension analysis."""
        if self.trades.empty:
            return {"error": "No trades loaded"}

        # Add computed columns
        self._add_session_column()
        self._add_day_column()
        self._add_hour_column()

        analysis = {
            "timestamp": datetime.now().isoformat(),
            "total_trades": len(self.trades),
            "dimensions": {}
        }

        # Analyze each dimension
        dim_configs = [
            ("Symbol", "symbol"),
            ("Session", "session"),
            ("DayOfWeek", "day_of_week"),
            ("Hour", "hour"),
        ]

        # Add strategy dimension if column exists
        if "Strategy" in self.trades.columns:
            dim_configs.append(("Strategy", "strategy"))
        if "SignalType" in self.trades.columns:
            dim_configs.append(("SignalType", "signal_type"))

        for col, name in dim_configs:
            if col in self.trades.columns:
                scores = self.analyze_dimension(col, name)
                analysis["dimensions"][name] = {
                    k: asdict(v) for k, v in scores.items()
                }

        # Overall stats
        pnl = self.trades["PnL"].dropna() if "PnL" in self.trades.columns else pd.Series()
        if len(pnl) > 0:
            wins_total = float(pnl[pnl > 0].sum())
            losses_total = abs(float(pnl[pnl < 0].sum()))
            analysis["overall"] = {
                "total_pnl": round(float(pnl.sum()), 2),
                "win_rate": round(float((pnl > 0).sum() / len(pnl) * 100), 1),
                "avg_pnl": round(float(pnl.mean()), 2),
                "profit_factor": round(wins_total / losses_total, 2) if losses_total > 0 else 999.0,
                "max_consec_losses": self._max_consec_losses(pnl.values),
                "sharpe": round(float(pnl.mean() / pnl.std() * np.sqrt(252)), 2) if pnl.std() > 0 else 0,
            }

        # Consistency check
        analysis["consistency"] = self._check_consistency()

        # Drawdown analysis
        analysis["drawdown"] = self._analyze_drawdown()

        # Generate combined recommendations
        analysis["recommendations"] = self._generate_all_recommendations(analysis)

        # Generate parameter adjustments
        analysis["parameter_adjustments"] = self._generate_parameter_adjustments(analysis)

        # Update learning state
        self._update_state(analysis)

        return analysis

    def _check_consistency(self) -> dict:
        """Check if trading respects 40% consistency rule."""
        if self.trades.empty or "PnL" not in self.trades.columns or "DateTime" not in self.trades.columns:
            return {"ok": True, "message": "No data"}

        pnl = self.trades["PnL"].dropna()
        total_profit = float(pnl.sum())
        if total_profit <= 0:
            return {"ok": True, "message": "No net profit"}

        daily_pnl = self.trades.groupby(self.trades["DateTime"].dt.date)["PnL"].sum()
        worst_day_pnl = float(daily_pnl.max())
        worst_day_pct = (worst_day_pnl / total_profit) * 100 if total_profit > 0 else 0

        return {
            "ok": worst_day_pct <= 40.0,
            "worst_day_pct": round(worst_day_pct, 1),
            "worst_day_pnl": round(worst_day_pnl, 2),
            "total_profit": round(total_profit, 2),
            "message": "OK" if worst_day_pct <= 40 else f"VIOLATION: {worst_day_pct:.1f}% > 40% max"
        }

    def _analyze_drawdown(self) -> dict:
        """Analyze drawdown patterns."""
        if self.trades.empty or "PnL" not in self.trades.columns:
            return {}

        pnl = self.trades["PnL"].dropna()
        cumulative = pnl.cumsum()
        peak = cumulative.cummax()
        drawdown = peak - cumulative

        return {
            "max_drawdown": round(float(drawdown.max()), 2),
            "avg_drawdown": round(float(drawdown.mean()), 2),
            "current_drawdown": round(float(drawdown.iloc[-1]), 2) if len(drawdown) > 0 else 0,
            "recovery_trades": int((drawdown == 0).sum()),
        }

    def _generate_all_recommendations(self, analysis: dict) -> List[dict]:
        """Generate prioritized recommendations from all dimensions."""
        recs = []

        for dim_name, dim_data in analysis.get("dimensions", {}).items():
            for value, score_data in dim_data.items():
                rec = score_data.get("recommendation", "")
                score = score_data.get("score", 50)
                trades = score_data.get("trades", 0)

                if trades < 5:
                    continue

                if "REMOVE" in rec:
                    recs.append({
                        "priority": "CRITICAL",
                        "dimension": dim_name,
                        "value": value,
                        "action": rec,
                        "score": score,
                        "trades": trades,
                    })
                elif "REDUCE" in rec:
                    recs.append({
                        "priority": "HIGH",
                        "dimension": dim_name,
                        "value": value,
                        "action": rec,
                        "score": score,
                        "trades": trades,
                    })

        # Consistency warning
        consistency = analysis.get("consistency", {})
        if not consistency.get("ok", True):
            recs.append({
                "priority": "CRITICAL",
                "dimension": "consistency",
                "value": "40% rule",
                "action": f"HALT - {consistency.get('message', '')}",
                "score": 0,
                "trades": analysis.get("total_trades", 0),
            })

        # Sort by priority
        priority_order = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3}
        recs.sort(key=lambda x: priority_order.get(x["priority"], 9))

        return recs

    def _generate_parameter_adjustments(self, analysis: dict) -> List[dict]:
        """Generate specific config parameter adjustments."""
        adjustments = []

        # --- Symbol adjustments ---
        symbol_data = analysis.get("dimensions", {}).get("symbol", {})
        for sym, data in symbol_data.items():
            score = data.get("score", 50)
            trades = data.get("trades", 0)
            if trades < 5:
                continue

            if score < 35:
                adjustments.append({
                    "file": "configs/symbols.json",
                    "parameter": f"{sym}.enabled",
                    "current": True,
                    "suggested": False,
                    "reason": f"Score {score}/100 - poor performance over {trades} trades",
                    "priority": "HIGH",
                })
            elif score < 50:
                adjustments.append({
                    "file": "configs/risk_params.json",
                    "parameter": f"risk_per_trade (for {sym})",
                    "current": 0.5,
                    "suggested": 0.25,
                    "reason": f"Score {score}/100 - reduce risk until improvement",
                    "priority": "MEDIUM",
                })

        # --- Session adjustments ---
        session_data = analysis.get("dimensions", {}).get("session", {})
        for session, data in session_data.items():
            score = data.get("score", 50)
            trades = data.get("trades", 0)
            if trades < 5:
                continue

            if score < 35:
                adjustments.append({
                    "file": "configs/risk_params.json",
                    "parameter": f"session.{session.lower()}.enabled",
                    "current": True,
                    "suggested": False,
                    "reason": f"{session} score {score}/100 over {trades} trades",
                    "priority": "HIGH",
                })

        # --- Day adjustments ---
        day_data = analysis.get("dimensions", {}).get("day_of_week", {})
        for day, data in day_data.items():
            score = data.get("score", 50)
            trades = data.get("trades", 0)
            if trades >= 5 and score < 35:
                adjustments.append({
                    "file": "configs/risk_params.json",
                    "parameter": f"trading_days.{day.lower()}",
                    "current": True,
                    "suggested": False,
                    "reason": f"{day} score {score}/100 over {trades} trades",
                    "priority": "MEDIUM",
                })

        # --- Drawdown adjustments ---
        dd = analysis.get("drawdown", {})
        max_dd = dd.get("max_drawdown", 0)
        if max_dd > 80:  # More than $80 DD on $2000 account = 4%
            adjustments.append({
                "file": "configs/risk_params.json",
                "parameter": "risk_per_trade",
                "current": 0.5,
                "suggested": 0.25,
                "reason": f"Max drawdown ${max_dd} approaching safety limits",
                "priority": "CRITICAL",
            })

        # --- Streak adjustments ---
        overall = analysis.get("overall", {})
        if overall.get("max_consec_losses", 0) >= 5:
            adjustments.append({
                "file": "configs/risk_params.json",
                "parameter": "max_consecutive_losses",
                "current": 5,
                "suggested": 3,
                "reason": f"Hit {overall['max_consec_losses']} consecutive losses",
                "priority": "HIGH",
            })

        return adjustments

    # --- State Management ---

    def _load_state(self):
        """Load persistent learning state."""
        if self.state_file.exists():
            try:
                with open(self.state_file) as f:
                    data = json.load(f)
                self.state.last_analysis = data.get("last_analysis", "")
                self.state.total_analyses = data.get("total_analyses", 0)
                self.state.parameter_history = data.get("parameter_history", {})
                self.state.active_adjustments = data.get("active_adjustments", [])
                self.state.improvement_log = data.get("improvement_log", [])
            except Exception:
                pass

    def _save_state(self):
        """Save learning state to disk."""
        data = {
            "last_analysis": self.state.last_analysis,
            "total_analyses": self.state.total_analyses,
            "parameter_history": self.state.parameter_history,
            "active_adjustments": self.state.active_adjustments,
            "improvement_log": self.state.improvement_log,
        }
        self.state_file.parent.mkdir(parents=True, exist_ok=True)
        with open(self.state_file, "w") as f:
            json.dump(data, f, indent=2, default=str)

    def _update_state(self, analysis: dict):
        """Update state with latest analysis results."""
        self.state.last_analysis = datetime.now().isoformat()
        self.state.total_analyses += 1

        # Store scores in history for trend detection
        for dim_name, dim_data in analysis.get("dimensions", {}).items():
            for value, score_data in dim_data.items():
                key = f"{dim_name}:{value}"
                if key not in self.state.parameter_history:
                    self.state.parameter_history[key] = []
                self.state.parameter_history[key].append({
                    "date": datetime.now().isoformat(),
                    "score": score_data.get("score", 50),
                    "trades": score_data.get("trades", 0),
                    "pnl": score_data.get("total_pnl", 0),
                })
                # Keep last 30 entries
                self.state.parameter_history[key] = self.state.parameter_history[key][-30:]

        # Store adjustments
        self.state.active_adjustments = analysis.get("parameter_adjustments", [])

        self._save_state()

    # --- Reporting ---

    def get_learning_summary(self) -> dict:
        """Get a summary of what the engine has learned."""
        return {
            "total_analyses": self.state.total_analyses,
            "last_analysis": self.state.last_analysis,
            "tracked_parameters": len(self.state.parameter_history),
            "active_adjustments": len(self.state.active_adjustments),
            "improving_parameters": sum(
                1 for key, hist in self.state.parameter_history.items()
                if len(hist) >= 2 and hist[-1].get("score", 0) > hist[-2].get("score", 0)
            ),
            "declining_parameters": sum(
                1 for key, hist in self.state.parameter_history.items()
                if len(hist) >= 2 and hist[-1].get("score", 0) < hist[-2].get("score", 0)
            ),
        }

    def print_analysis(self, analysis: dict):
        """Print a human-readable analysis report."""
        print("\n" + "=" * 70)
        print("  SELF-LEARNING ENGINE - ANALYSIS REPORT")
        print(f"  {analysis.get('timestamp', '')}")
        print("=" * 70)

        overall = analysis.get("overall", {})
        print(f"\nTotal Trades: {analysis.get('total_trades', 0)}")
        print(f"Win Rate: {overall.get('win_rate', 0)}%")
        print(f"Profit Factor: {overall.get('profit_factor', 0)}")
        print(f"Total PnL: ${overall.get('total_pnl', 0)}")
        print(f"Sharpe: {overall.get('sharpe', 0)}")

        for dim_name, dim_data in analysis.get("dimensions", {}).items():
            print(f"\n--- {dim_name.upper()} ANALYSIS ---")
            for value, data in sorted(dim_data.items(), key=lambda x: x[1].get("score", 0)):
                score = data.get("score", 0)
                bar = "#" * int(score / 5)
                trend_icon = {"improving": "+", "declining": "-", "stable": "="}
                print(f"  {value:12s} | Score: {score:5.1f} [{bar:20s}] "
                      f"| WR: {data.get('win_rate', 0):5.1f}% "
                      f"| PF: {data.get('profit_factor', 0):5.2f} "
                      f"| PnL: ${data.get('total_pnl', 0):8.2f} "
                      f"| {data.get('trades', 0):3d} trades "
                      f"| {trend_icon.get(data.get('trend', 'stable'), '=')} "
                      f"| {data.get('recommendation', '')}")

        # Consistency
        consistency = analysis.get("consistency", {})
        print(f"\n--- CONSISTENCY RULE (40%) ---")
        print(f"  Status: {'OK' if consistency.get('ok', True) else 'VIOLATION'}")
        print(f"  Worst day: {consistency.get('worst_day_pct', 0):.1f}% of total profit")

        # Recommendations
        recs = analysis.get("recommendations", [])
        if recs:
            print(f"\n--- RECOMMENDATIONS ({len(recs)}) ---")
            for rec in recs:
                print(f"  [{rec['priority']:8s}] {rec['dimension']:12s} > "
                      f"{rec['value']:12s} : {rec['action']}")

        # Parameter adjustments
        adj = analysis.get("parameter_adjustments", [])
        if adj:
            print(f"\n--- PARAMETER ADJUSTMENTS ({len(adj)}) ---")
            for a in adj:
                print(f"  [{a['priority']:8s}] {a['parameter']}: "
                      f"{a['current']} -> {a['suggested']} | {a['reason']}")

        print("\n" + "=" * 70)


def main():
    """Run analysis standalone."""
    engine = SelfLearningEngine()
    n = engine.load_trades()
    if n == 0:
        print("No trades found. Provide journal CSV path or place files in backtest_results/")
        return

    engine.load_configs()
    analysis = engine.run_full_analysis()
    engine.print_analysis(analysis)

    # Save report
    out_dir = Path(__file__).parent.parent / "backtest_results" / "learning"
    out_dir.mkdir(parents=True, exist_ok=True)
    report_file = out_dir / f"learning_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(report_file, "w") as f:
        json.dump(analysis, f, indent=2, default=str)
    print(f"\nReport saved to {report_file}")


if __name__ == "__main__":
    main()
