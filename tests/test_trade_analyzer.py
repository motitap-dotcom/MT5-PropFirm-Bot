"""
Trade analyzer tests — validates per-symbol, per-session, per-day analysis
and recommendation generation.
"""

from datetime import datetime

import pandas as pd
import pytest

from trade_analyzer import TradeAnalyzer


def make_trades(trade_dicts):
    """Helper to create a DataFrame of trades."""
    return pd.DataFrame(trade_dicts)


@pytest.fixture
def analyzer():
    a = TradeAnalyzer(journal_dir="/tmp/nonexistent", output_dir="/tmp/test_output")
    return a


# --- analyze_by_symbol ---

class TestAnalyzeBySymbol:

    def test_multiple_symbols(self, analyzer):
        analyzer.trades = make_trades([
            {"Symbol": "EURUSD", "PnL": 10, "DateTime": datetime(2025, 1, 6, 9)},
            {"Symbol": "EURUSD", "PnL": -5, "DateTime": datetime(2025, 1, 6, 10)},
            {"Symbol": "GBPUSD", "PnL": 15, "DateTime": datetime(2025, 1, 6, 9)},
        ])
        result = analyzer.analyze_by_symbol()
        assert "EURUSD" in result
        assert "GBPUSD" in result
        assert result["EURUSD"]["trades"] == 2
        assert result["EURUSD"]["total_pnl"] == 5
        assert result["GBPUSD"]["trades"] == 1

    def test_poor_win_rate_recommends_remove(self, analyzer):
        """Symbol with <30% win rate over 5+ trades should get REMOVE."""
        analyzer.trades = make_trades([
            {"Symbol": "USDJPY", "PnL": -5, "DateTime": datetime(2025, 1, d, 9)}
            for d in range(6, 11)
        ] + [
            {"Symbol": "USDJPY", "PnL": 10, "DateTime": datetime(2025, 1, 11, 9)}
        ])
        result = analyzer.analyze_by_symbol()
        assert result["USDJPY"]["win_rate"] < 30
        assert "REMOVE" in result["USDJPY"]["recommendation"]

    def test_strong_performer_recommends_keep(self, analyzer):
        """Symbol with >55% win rate and PF>1.5 should get KEEP."""
        analyzer.trades = make_trades([
            {"Symbol": "EURUSD", "PnL": 10, "DateTime": datetime(2025, 1, d, 9)}
            for d in range(6, 11)
        ] + [
            {"Symbol": "EURUSD", "PnL": -3, "DateTime": datetime(2025, 1, 11, 9)}
        ])
        result = analyzer.analyze_by_symbol()
        assert result["EURUSD"]["win_rate"] > 55
        assert "KEEP" in result["EURUSD"]["recommendation"]

    def test_empty_trades(self, analyzer):
        analyzer.trades = pd.DataFrame()
        assert analyzer.analyze_by_symbol() == {}

    def test_missing_pnl_column(self, analyzer):
        analyzer.trades = make_trades([
            {"Symbol": "EURUSD", "DateTime": datetime(2025, 1, 6, 9)},
        ])
        result = analyzer.analyze_by_symbol()
        assert result == {}


# --- analyze_by_session ---

class TestAnalyzeBySession:

    def test_london_session(self, analyzer):
        analyzer.trades = make_trades([
            {"DateTime": datetime(2025, 1, 6, 9, 0), "PnL": 10},
        ])
        result = analyzer.analyze_by_session()
        assert result["London"]["trades"] == 1

    def test_ny_session(self, analyzer):
        analyzer.trades = make_trades([
            {"DateTime": datetime(2025, 1, 6, 14, 0), "PnL": 10},
        ])
        result = analyzer.analyze_by_session()
        assert result["NewYork"]["trades"] == 1

    def test_other_session(self, analyzer):
        analyzer.trades = make_trades([
            {"DateTime": datetime(2025, 1, 6, 2, 0), "PnL": 10},
        ])
        result = analyzer.analyze_by_session()
        assert result["Other"]["trades"] == 1

    def test_boundary_12_is_ny(self, analyzer):
        """Trade at exactly 12:00 should be NewYork."""
        analyzer.trades = make_trades([
            {"DateTime": datetime(2025, 1, 6, 12, 0), "PnL": 10},
        ])
        result = analyzer.analyze_by_session()
        assert result["NewYork"]["trades"] == 1

    def test_empty_trades(self, analyzer):
        analyzer.trades = pd.DataFrame()
        assert analyzer.analyze_by_session() == {}


# --- analyze_by_day_of_week ---

class TestAnalyzeByDay:

    def test_all_weekdays(self, analyzer):
        analyzer.trades = make_trades([
            {"DateTime": datetime(2025, 1, 6, 9), "PnL": 10},   # Monday
            {"DateTime": datetime(2025, 1, 7, 9), "PnL": 10},   # Tuesday
            {"DateTime": datetime(2025, 1, 8, 9), "PnL": 10},   # Wednesday
            {"DateTime": datetime(2025, 1, 9, 9), "PnL": 10},   # Thursday
            {"DateTime": datetime(2025, 1, 10, 9), "PnL": 10},  # Friday
        ])
        result = analyzer.analyze_by_day_of_week()
        for day in ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]:
            assert result[day]["trades"] == 1

    def test_empty_trades(self, analyzer):
        analyzer.trades = pd.DataFrame()
        assert analyzer.analyze_by_day_of_week() == {}


# --- analyze_streaks ---

class TestAnalyzeStreaks:

    def test_five_consecutive_losses(self, analyzer):
        analyzer.trades = make_trades([
            {"PnL": -5} for _ in range(5)
        ])
        result = analyzer.analyze_streaks()
        assert result["max_loss_streak"] == 5

    def test_alternating_wl(self, analyzer):
        analyzer.trades = make_trades([
            {"PnL": 10}, {"PnL": -5}, {"PnL": 10}, {"PnL": -5},
        ])
        result = analyzer.analyze_streaks()
        assert result["max_win_streak"] == 1
        assert result["max_loss_streak"] == 1

    def test_empty_trades(self, analyzer):
        analyzer.trades = pd.DataFrame()
        assert analyzer.analyze_streaks() == {}

    def test_all_wins(self, analyzer):
        analyzer.trades = make_trades([{"PnL": 10} for _ in range(3)])
        result = analyzer.analyze_streaks()
        assert result["max_win_streak"] == 3
        assert result["max_loss_streak"] == 0


# --- generate_recommendations ---

class TestRecommendations:

    def test_remove_poor_symbol(self, analyzer):
        analyzer.trades = make_trades([
            {"Symbol": "USDJPY", "PnL": -5, "DateTime": datetime(2025, 1, d, 9)}
            for d in range(6, 12)
        ])
        recs = analyzer.generate_recommendations()
        assert any(r["action"].startswith("Remove USDJPY") for r in recs)

    def test_no_recommendations_for_good_data(self, analyzer):
        analyzer.trades = make_trades([
            {"Symbol": "EURUSD", "PnL": 10, "DateTime": datetime(2025, 1, d, 9)}
            for d in range(6, 10)
        ])
        recs = analyzer.generate_recommendations()
        # With only 4 trades, no symbol-based recommendation (needs >= 5)
        symbol_recs = [r for r in recs if r["type"] == "SYMBOL"]
        assert len(symbol_recs) == 0
