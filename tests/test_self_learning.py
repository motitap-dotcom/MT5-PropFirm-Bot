"""
Tests for the Self-Learning Engine.
Validates analysis, scoring, recommendations, consistency checks,
and parameter adjustment generation.
"""

from datetime import datetime, timedelta
import pandas as pd
import pytest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "python"))

from self_learning_engine import SelfLearningEngine, ParameterScore


@pytest.fixture
def engine(tmp_path):
    return SelfLearningEngine(
        journal_dir=tmp_path,
        config_dir=tmp_path,
        state_file=tmp_path / "test_state.json",
    )


def make_trades(records):
    return pd.DataFrame(records)


# --- Dimension Analysis ---

class TestDimensionAnalysis:

    def test_symbol_analysis(self, engine):
        engine.load_trades_from_dataframe(make_trades([
            {"Symbol": "EURUSD", "PnL": 10, "DateTime": datetime(2025, 1, 6, 9)},
            {"Symbol": "EURUSD", "PnL": -5, "DateTime": datetime(2025, 1, 7, 9)},
            {"Symbol": "GBPUSD", "PnL": 15, "DateTime": datetime(2025, 1, 6, 10)},
        ]))
        result = engine.analyze_dimension("Symbol", "symbol")
        assert "EURUSD" in result
        assert "GBPUSD" in result
        assert result["EURUSD"].trades == 2
        assert result["EURUSD"].wins == 1
        assert result["EURUSD"].losses == 1
        assert result["EURUSD"].total_pnl == 5

    def test_session_analysis(self, engine):
        engine.load_trades_from_dataframe(make_trades([
            {"Session": "London", "PnL": 10, "DateTime": datetime(2025, 1, 6, 9)},
            {"Session": "London", "PnL": 5, "DateTime": datetime(2025, 1, 7, 9)},
            {"Session": "NewYork", "PnL": -3, "DateTime": datetime(2025, 1, 6, 14)},
        ]))
        result = engine.analyze_dimension("Session", "session")
        assert result["London"].win_rate == 100.0
        assert result["NewYork"].win_rate == 0.0

    def test_empty_trades(self, engine):
        engine.load_trades_from_dataframe(pd.DataFrame())
        result = engine.analyze_dimension("Symbol", "symbol")
        assert result == {}

    def test_no_pnl_column(self, engine):
        engine.load_trades_from_dataframe(make_trades([
            {"Symbol": "EURUSD", "DateTime": datetime(2025, 1, 6, 9)}
        ]))
        result = engine.analyze_dimension("Symbol", "symbol")
        assert result == {}

    def test_breakeven_not_counted_as_loss(self, engine):
        engine.load_trades_from_dataframe(make_trades([
            {"Symbol": "EURUSD", "PnL": 10, "DateTime": datetime(2025, 1, 6, 9)},
            {"Symbol": "EURUSD", "PnL": 0, "DateTime": datetime(2025, 1, 7, 9)},
            {"Symbol": "EURUSD", "PnL": -5, "DateTime": datetime(2025, 1, 8, 9)},
        ]))
        result = engine.analyze_dimension("Symbol", "symbol")
        assert result["EURUSD"].wins == 1
        assert result["EURUSD"].losses == 1
        assert result["EURUSD"].breakevens == 1

    def test_profit_factor_all_wins(self, engine):
        engine.load_trades_from_dataframe(make_trades([
            {"Symbol": "EURUSD", "PnL": 10, "DateTime": datetime(2025, 1, d, 9)}
            for d in range(6, 12)
        ]))
        result = engine.analyze_dimension("Symbol", "symbol")
        assert result["EURUSD"].profit_factor == 999.0

    def test_profit_factor_mixed(self, engine):
        engine.load_trades_from_dataframe(make_trades([
            {"Symbol": "EURUSD", "PnL": 20, "DateTime": datetime(2025, 1, 6, 9)},
            {"Symbol": "EURUSD", "PnL": -10, "DateTime": datetime(2025, 1, 7, 9)},
        ]))
        result = engine.analyze_dimension("Symbol", "symbol")
        assert result["EURUSD"].profit_factor == 2.0


# --- Scoring ---

class TestScoring:

    def test_excellent_score(self, engine):
        s = ParameterScore(name="test", value="A", trades=10, wins=8, losses=2,
                           win_rate=80, profit_factor=3.0, avg_win=15, avg_loss=-5,
                           total_pnl=100)
        score = engine._compute_score(s)
        assert score >= 80

    def test_poor_score(self, engine):
        s = ParameterScore(name="test", value="B", trades=10, wins=2, losses=8,
                           win_rate=20, profit_factor=0.5, avg_win=5, avg_loss=-10,
                           total_pnl=-70, max_consec_losses=6)
        score = engine._compute_score(s)
        assert score < 30

    def test_insufficient_data(self, engine):
        s = ParameterScore(name="test", value="C", trades=2)
        score = engine._compute_score(s)
        assert score == 50.0

    def test_score_bounded_0_100(self, engine):
        # Extremely bad
        s = ParameterScore(name="test", value="X", trades=100, wins=0, losses=100,
                           win_rate=0, profit_factor=0, avg_win=0, avg_loss=-100,
                           total_pnl=-10000, max_consec_losses=100)
        assert engine._compute_score(s) >= 0
        assert engine._compute_score(s) <= 100


# --- Recommendations ---

class TestRecommendations:

    def test_remove_poor_symbol(self, engine):
        engine.load_trades_from_dataframe(make_trades([
            {"Symbol": "USDJPY", "PnL": -10, "DateTime": datetime(2025, 1, d, 9)}
            for d in range(6, 14)
        ]))
        analysis = engine.run_full_analysis()
        recs = analysis["recommendations"]
        assert any("REMOVE" in r.get("action", "") for r in recs)

    def test_no_recs_for_good_data(self, engine):
        engine.load_trades_from_dataframe(make_trades([
            {"Symbol": "EURUSD", "PnL": 10, "DateTime": datetime(2025, 1, d, 9)}
            for d in range(6, 14)
        ]))
        analysis = engine.run_full_analysis()
        recs = analysis["recommendations"]
        assert not any("REMOVE" in r.get("action", "") for r in recs)

    def test_consistency_violation(self, engine):
        """One big win day that's >40% of total."""
        trades = [
            {"Symbol": "EURUSD", "PnL": 100, "DateTime": datetime(2025, 1, 6, 9)},
        ] + [
            {"Symbol": "EURUSD", "PnL": 5, "DateTime": datetime(2025, 1, d, 9)}
            for d in range(7, 12)
        ]
        engine.load_trades_from_dataframe(make_trades(trades))
        analysis = engine.run_full_analysis()
        assert analysis["consistency"]["ok"] is False
        assert analysis["consistency"]["worst_day_pct"] > 40

    def test_consistency_ok(self, engine):
        """Even profit across days."""
        trades = [
            {"Symbol": "EURUSD", "PnL": 10, "DateTime": datetime(2025, 1, d, 9)}
            for d in range(6, 11)
        ]
        engine.load_trades_from_dataframe(make_trades(trades))
        analysis = engine.run_full_analysis()
        assert analysis["consistency"]["ok"] is True


# --- Drawdown Analysis ---

class TestDrawdown:

    def test_drawdown_calculation(self, engine):
        engine.load_trades_from_dataframe(make_trades([
            {"Symbol": "EURUSD", "PnL": 20, "DateTime": datetime(2025, 1, 6, 9)},
            {"Symbol": "EURUSD", "PnL": -30, "DateTime": datetime(2025, 1, 7, 9)},
            {"Symbol": "EURUSD", "PnL": 15, "DateTime": datetime(2025, 1, 8, 9)},
        ]))
        analysis = engine.run_full_analysis()
        dd = analysis["drawdown"]
        assert dd["max_drawdown"] > 0

    def test_no_drawdown_all_wins(self, engine):
        engine.load_trades_from_dataframe(make_trades([
            {"Symbol": "EURUSD", "PnL": 10, "DateTime": datetime(2025, 1, d, 9)}
            for d in range(6, 10)
        ]))
        analysis = engine.run_full_analysis()
        assert analysis["drawdown"]["max_drawdown"] == 0


# --- Parameter Adjustments ---

class TestParameterAdjustments:

    def test_disable_losing_symbol(self, engine):
        engine.load_trades_from_dataframe(make_trades([
            {"Symbol": "USDJPY", "PnL": -10, "DateTime": datetime(2025, 1, d, 9)}
            for d in range(6, 16)
        ]))
        analysis = engine.run_full_analysis()
        adj = analysis["parameter_adjustments"]
        symbol_adj = [a for a in adj if "USDJPY" in a.get("parameter", "")]
        assert len(symbol_adj) > 0

    def test_no_adjustments_for_winner(self, engine):
        engine.load_trades_from_dataframe(make_trades([
            {"Symbol": "EURUSD", "PnL": 10, "DateTime": datetime(2025, 1, d, 9)}
            for d in range(6, 16)
        ]))
        analysis = engine.run_full_analysis()
        adj = analysis["parameter_adjustments"]
        symbol_adj = [a for a in adj if "EURUSD" in a.get("parameter", "")]
        assert len(symbol_adj) == 0


# --- Consecutive Losses ---

class TestConsecutiveLosses:

    def test_max_consec(self, engine):
        assert engine._max_consec_losses([10, -5, -5, -5, 10, -5]) == 3

    def test_all_wins(self, engine):
        assert engine._max_consec_losses([10, 5, 15]) == 0

    def test_all_losses(self, engine):
        assert engine._max_consec_losses([-5, -10, -3, -7]) == 4

    def test_empty(self, engine):
        assert engine._max_consec_losses([]) == 0


# --- Session/Day Column Generation ---

class TestColumnGeneration:

    def test_session_column(self, engine):
        engine.load_trades_from_dataframe(make_trades([
            {"PnL": 10, "DateTime": datetime(2025, 1, 6, 8)},   # London
            {"PnL": 10, "DateTime": datetime(2025, 1, 6, 14)},  # NY
            {"PnL": 10, "DateTime": datetime(2025, 1, 6, 3)},   # Other
        ]))
        engine._add_session_column()
        sessions = engine.trades["Session"].tolist()
        assert sessions == ["London", "NewYork", "Other"]

    def test_day_column(self, engine):
        engine.load_trades_from_dataframe(make_trades([
            {"PnL": 10, "DateTime": datetime(2025, 1, 6, 9)},   # Monday
            {"PnL": 10, "DateTime": datetime(2025, 1, 10, 9)},  # Friday
        ]))
        engine._add_day_column()
        days = engine.trades["DayOfWeek"].tolist()
        assert days == ["Monday", "Friday"]


# --- State Persistence ---

class TestStatePersistence:

    def test_save_and_load(self, engine, tmp_path):
        engine.load_trades_from_dataframe(make_trades([
            {"Symbol": "EURUSD", "PnL": 10, "DateTime": datetime(2025, 1, d, 9)}
            for d in range(6, 12)
        ]))
        engine.run_full_analysis()

        # Create new engine with same state file
        engine2 = SelfLearningEngine(
            journal_dir=tmp_path, config_dir=tmp_path,
            state_file=tmp_path / "test_state.json"
        )
        assert engine2.state.total_analyses == 1
        assert len(engine2.state.parameter_history) > 0

    def test_trend_detection(self, engine, tmp_path):
        """Run analysis twice to detect trends."""
        # First run: bad
        engine.load_trades_from_dataframe(make_trades([
            {"Symbol": "EURUSD", "PnL": -5, "DateTime": datetime(2025, 1, d, 9)}
            for d in range(6, 12)
        ]))
        engine.run_full_analysis()

        # Second run: better
        engine.load_trades_from_dataframe(make_trades([
            {"Symbol": "EURUSD", "PnL": 10, "DateTime": datetime(2025, 1, d, 9)}
            for d in range(6, 12)
        ]))
        analysis = engine.run_full_analysis()

        # Should detect improvement
        sym_data = analysis["dimensions"].get("symbol", {})
        if "EURUSD" in sym_data:
            assert sym_data["EURUSD"]["score"] > 50


# --- Full Analysis ---

class TestFullAnalysis:

    def test_full_analysis_structure(self, engine):
        engine.load_trades_from_dataframe(make_trades([
            {"Symbol": "EURUSD", "PnL": 10, "DateTime": datetime(2025, 1, 6, 9)},
            {"Symbol": "GBPUSD", "PnL": -5, "DateTime": datetime(2025, 1, 7, 14)},
        ]))
        analysis = engine.run_full_analysis()
        assert "timestamp" in analysis
        assert "dimensions" in analysis
        assert "overall" in analysis
        assert "consistency" in analysis
        assert "drawdown" in analysis
        assert "recommendations" in analysis
        assert "parameter_adjustments" in analysis

    def test_hour_dimension(self, engine):
        engine.load_trades_from_dataframe(make_trades([
            {"PnL": 10, "DateTime": datetime(2025, 1, 6, 9)},
            {"PnL": -5, "DateTime": datetime(2025, 1, 6, 14)},
        ]))
        analysis = engine.run_full_analysis()
        assert "hour" in analysis["dimensions"]

    def test_overall_sharpe(self, engine):
        engine.load_trades_from_dataframe(make_trades([
            {"Symbol": "EURUSD", "PnL": 10, "DateTime": datetime(2025, 1, d, 9)}
            for d in range(6, 11)
        ] + [
            {"Symbol": "EURUSD", "PnL": -3, "DateTime": datetime(2025, 1, 11, 9)}
        ]))
        analysis = engine.run_full_analysis()
        # All same PnL except one — should have a positive sharpe
        assert analysis["overall"]["sharpe"] > 0
