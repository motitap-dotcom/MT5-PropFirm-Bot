"""Tests for futures_bot.core.guardian — TradeDay rules enforcement."""

from __future__ import annotations

import pytest

from futures_bot.core.guardian import DailyPnL, Guardian, GuardianState


# ── update_balance: drawdown state machine ──

class TestDrawdownStateMachine:

    def test_fresh_guardian_is_active(self, guardian_config):
        g = Guardian(guardian_config)
        assert g.state == GuardianState.ACTIVE
        assert g.total_pnl == 0.0

    def test_small_drawdown_stays_active(self, guardian_config):
        g = Guardian(guardian_config)
        # 59% of $2,000 = $1,180 loss -> still ACTIVE (below 60% warning)
        g.update_balance(48820.0)
        assert g.state == GuardianState.ACTIVE

    def test_warning_threshold_triggers_caution(self, guardian_config):
        g = Guardian(guardian_config)
        # 60% of $2,000 = $1,200 loss
        g.update_balance(48800.0)
        assert g.state == GuardianState.CAUTION

    def test_critical_threshold_triggers_halted(self, guardian_config):
        g = Guardian(guardian_config)
        # 80% of $2,000 = $1,600 loss
        g.update_balance(48400.0)
        assert g.state == GuardianState.HALTED

    def test_emergency_threshold_triggers_emergency(self, guardian_config):
        g = Guardian(guardian_config)
        # 90% of $2,000 = $1,800 loss
        g.update_balance(48200.0)
        assert g.state == GuardianState.EMERGENCY
        assert g.must_close_all() is True

    def test_full_drawdown_triggers_shutdown(self, guardian_config):
        g = Guardian(guardian_config)
        # Equal to min_balance -> SHUTDOWN
        g.update_balance(48000.0)
        assert g.state == GuardianState.SHUTDOWN

    def test_below_min_balance_triggers_shutdown(self, guardian_config):
        g = Guardian(guardian_config)
        g.update_balance(47500.0)
        assert g.state == GuardianState.SHUTDOWN

    def test_shutdown_is_sticky(self, guardian_config):
        """Once SHUTDOWN, recovery to positive balance should not reset state."""
        g = Guardian(guardian_config)
        g.update_balance(47000.0)  # SHUTDOWN
        assert g.state == GuardianState.SHUTDOWN
        g.update_balance(50500.0)  # recover (shouldn't happen IRL)
        assert g.state == GuardianState.SHUTDOWN

    def test_unrealized_pnl_counts_toward_drawdown(self, guardian_config):
        """Unrealized losses must trigger guardian states too."""
        g = Guardian(guardian_config)
        # realized balance fine, but unrealized loss blows 80% threshold
        g.update_balance(current_balance=50000.0, unrealized_pnl=-1700.0)
        assert g.state == GuardianState.HALTED

    def test_recovery_from_caution_to_active(self, guardian_config):
        """If drawdown shrinks, state should come back down (but not from SHUTDOWN)."""
        g = Guardian(guardian_config)
        g.update_balance(48800.0)  # CAUTION
        assert g.state == GuardianState.CAUTION
        g.update_balance(49500.0)  # below warning
        assert g.state == GuardianState.ACTIVE


# ── can_open_trade ──

class TestCanOpenTrade:

    def test_active_state_allows_trade(self, guardian_config):
        g = Guardian(guardian_config)
        ok, reason = g.can_open_trade(num_contracts=1, is_micro=True)
        assert ok is True
        assert reason == "OK"

    def test_halted_state_blocks_trade(self, guardian_config):
        g = Guardian(guardian_config)
        g.update_balance(48400.0)  # HALTED
        ok, reason = g.can_open_trade()
        assert ok is False
        assert "halted" in reason.lower()

    def test_daily_loss_limit_blocks_trade(self, guardian_config):
        g = Guardian(guardian_config)
        g.daily_pnl = -400.0  # exactly at limit
        ok, reason = g.can_open_trade()
        assert ok is False
        assert "daily loss" in reason.lower()

    def test_daily_profit_limit_blocks_trade(self, guardian_config):
        """Consistency rule: stop if daily profit hits $900."""
        g = Guardian(guardian_config)
        g.daily_pnl = 900.0
        ok, reason = g.can_open_trade()
        assert ok is False
        assert "consistency" in reason.lower() or "profit" in reason.lower()

    def test_max_daily_trades_blocks(self, guardian_config):
        g = Guardian(guardian_config)
        g.daily_trades = 6
        ok, reason = g.can_open_trade()
        assert ok is False
        assert "daily trades" in reason.lower()

    def test_micro_contract_over_limit_blocks(self, guardian_config):
        g = Guardian(guardian_config)
        ok, reason = g.can_open_trade(num_contracts=51, is_micro=True)
        assert ok is False

    def test_standard_contract_over_limit_blocks(self, guardian_config):
        g = Guardian(guardian_config)
        ok, reason = g.can_open_trade(num_contracts=6, is_micro=False)
        assert ok is False

    def test_caution_allows_trade_with_warning(self, guardian_config):
        g = Guardian(guardian_config)
        g.update_balance(48800.0)  # CAUTION
        ok, reason = g.can_open_trade()
        assert ok is True
        assert "caution" in reason.lower()


# ── record_trade / start_new_day ──

class TestTradeAccounting:

    def test_record_trade_updates_totals(self, guardian_config):
        g = Guardian(guardian_config)
        g.record_trade(150.0)
        assert g.daily_pnl == 150.0
        assert g.daily_trades == 1
        assert g.total_pnl == 150.0

    def test_record_multiple_trades(self, guardian_config):
        g = Guardian(guardian_config)
        g.record_trade(100.0)
        g.record_trade(-50.0)
        g.record_trade(200.0)
        assert g.daily_pnl == 250.0
        assert g.daily_trades == 3
        assert g.total_pnl == 250.0

    def test_start_new_day_archives_history_and_resets(self, guardian_config):
        g = Guardian(guardian_config)
        g.record_trade(250.0)
        g.record_trade(-50.0)
        g.start_new_day("2026-04-22")
        assert g.daily_pnl == 0.0
        assert g.daily_trades == 0
        assert g.trading_days == 1
        assert g.total_pnl == 200.0  # preserved
        assert len(g.daily_history) == 1
        assert g.daily_history[0].pnl == 200.0
        assert g.daily_history[0].trades == 2

    def test_new_day_without_trades_does_not_count(self, guardian_config):
        """Days with zero trades should not count toward min_trading_days."""
        g = Guardian(guardian_config)
        g.start_new_day("2026-04-22")
        assert g.trading_days == 0
        assert g.daily_history == []

    def test_new_day_resets_state_from_caution(self, guardian_config):
        g = Guardian(guardian_config)
        g.update_balance(48800.0)  # CAUTION
        assert g.state == GuardianState.CAUTION
        g.record_trade(10.0)  # so that day counts
        g.start_new_day("2026-04-23")
        assert g.state == GuardianState.ACTIVE

    def test_new_day_does_not_reset_shutdown(self, guardian_config):
        g = Guardian(guardian_config)
        g.update_balance(47000.0)  # SHUTDOWN
        g.record_trade(-1.0)
        g.start_new_day("2026-04-23")
        assert g.state == GuardianState.SHUTDOWN


# ── _check_consistency (30% rule) ──

class TestConsistencyRule:

    def test_no_history_passes(self, guardian_config):
        g = Guardian(guardian_config)
        assert g._check_consistency() is True

    def test_non_positive_total_pnl_passes(self, guardian_config):
        g = Guardian(guardian_config)
        g.daily_history.append(DailyPnL("2026-04-21", 100.0, 1))
        g.total_pnl = -50.0
        assert g._check_consistency() is True

    def test_single_day_30_pct_exactly_passes(self, guardian_config):
        """Exact 30% is NOT a violation (the rule is strictly greater)."""
        g = Guardian(guardian_config)
        g.total_pnl = 1000.0
        g.daily_history.append(DailyPnL("2026-04-21", 300.0, 1))
        assert g._check_consistency() is True

    def test_single_day_over_30_pct_fails(self, guardian_config):
        g = Guardian(guardian_config)
        g.total_pnl = 1000.0
        g.daily_history.append(DailyPnL("2026-04-21", 400.0, 1))
        assert g._check_consistency() is False

    def test_losing_day_ignored_in_consistency(self, guardian_config):
        """Losing days should not trigger consistency failure."""
        g = Guardian(guardian_config)
        g.total_pnl = 100.0
        # A -$500 day would otherwise be 500% of total; rule only applies to wins.
        g.daily_history.append(DailyPnL("2026-04-21", -500.0, 1))
        g.daily_history.append(DailyPnL("2026-04-22", 600.0, 1))
        # 600/100 = 6x which is > 30%, so this SHOULD fail.
        assert g._check_consistency() is False

    def test_balanced_days_pass(self, guardian_config):
        g = Guardian(guardian_config)
        g.total_pnl = 3000.0
        g.daily_history.extend([
            DailyPnL("d1", 800.0, 2),  # 26.6%
            DailyPnL("d2", 700.0, 2),  # 23.3%
            DailyPnL("d3", 600.0, 2),  # 20.0%
            DailyPnL("d4", 500.0, 2),  # 16.6%
            DailyPnL("d5", 400.0, 2),  # 13.3%
        ])
        assert g._check_consistency() is True


# ── is_evaluation_passed ──

class TestEvaluationPass:

    def test_all_conditions_met_passes(self, guardian_config):
        g = Guardian(guardian_config)
        g.total_pnl = 3000.0
        g.daily_history = [
            DailyPnL(f"d{i}", 600.0, 1) for i in range(5)
        ]
        g.trading_days = 5
        assert g.is_evaluation_passed() is True

    def test_insufficient_profit_fails(self, guardian_config):
        g = Guardian(guardian_config)
        g.total_pnl = 2999.0
        g.trading_days = 5
        assert g.is_evaluation_passed() is False

    def test_insufficient_days_fails(self, guardian_config):
        g = Guardian(guardian_config)
        g.total_pnl = 3000.0
        g.trading_days = 4
        assert g.is_evaluation_passed() is False

    def test_consistency_failure_fails_eval(self, guardian_config):
        g = Guardian(guardian_config)
        g.total_pnl = 3000.0
        g.trading_days = 5
        # One day with > 30% of total
        g.daily_history = [DailyPnL("big", 2000.0, 1)] + [
            DailyPnL(f"d{i}", 250.0, 1) for i in range(4)
        ]
        assert g.is_evaluation_passed() is False

    def test_update_balance_triggers_pass_on_success(self, guardian_config):
        g = Guardian(guardian_config)
        # Seed a valid, consistent history reaching profit target.
        g.daily_history = [DailyPnL(f"d{i}", 600.0, 1) for i in range(5)]
        g.trading_days = 5
        g.update_balance(53000.0)
        assert g.state == GuardianState.SHUTDOWN
        assert "PASSED" in g.reason


# ── get_max_risk_per_trade ──

class TestMaxRiskPerTrade:

    def test_active_returns_full_budget(self, guardian_config):
        g = Guardian(guardian_config)
        assert g.get_max_risk_per_trade() == 150.0

    def test_caution_halves_budget(self, guardian_config):
        g = Guardian(guardian_config)
        g.update_balance(48800.0)  # CAUTION
        assert g.get_max_risk_per_trade() == 75.0

    def test_halted_zeros_budget(self, guardian_config):
        g = Guardian(guardian_config)
        g.update_balance(48400.0)  # HALTED
        assert g.get_max_risk_per_trade() == 0.0

    def test_daily_budget_constrains_risk(self, guardian_config):
        """If only $50 daily loss budget remains, risk should shrink."""
        g = Guardian(guardian_config)
        g.daily_pnl = -350.0  # $50 remaining before hitting -$400 limit
        assert g.get_max_risk_per_trade() == 50.0

    def test_exhausted_daily_budget_returns_zero(self, guardian_config):
        g = Guardian(guardian_config)
        g.daily_pnl = -500.0  # already past daily limit
        assert g.get_max_risk_per_trade() == 0.0


# ── get_status ──

class TestGetStatus:

    def test_status_has_required_keys(self, guardian_config):
        g = Guardian(guardian_config)
        s = g.get_status()
        for key in [
            "state", "balance", "total_pnl", "daily_pnl", "daily_trades",
            "trading_days", "drawdown_used", "drawdown_remaining",
            "profit_target_remaining", "consistency_ok", "reason", "timestamp",
        ]:
            assert key in s

    def test_drawdown_used_non_negative_when_in_profit(self, guardian_config):
        g = Guardian(guardian_config)
        g.update_balance(51000.0)
        s = g.get_status()
        assert s["drawdown_used"] == 0  # clamped at 0

    def test_drawdown_used_reflects_loss(self, guardian_config):
        g = Guardian(guardian_config)
        g.update_balance(49000.0)
        s = g.get_status()
        assert s["drawdown_used"] == pytest.approx(1000.0)
        assert s["drawdown_remaining"] == pytest.approx(1000.0)
