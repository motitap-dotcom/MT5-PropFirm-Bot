"""
Config validation tests — prevents catastrophic prop firm rule breaches.
Validates all 6 JSON config files for schema, FundedNext rules, and cross-config consistency.
"""

import json
from pathlib import Path

import pytest

CONFIGS_DIR = Path(__file__).parent.parent / "configs"


def load_config(name):
    with open(CONFIGS_DIR / name) as f:
        return json.load(f)


# --- JSON Validity ---

@pytest.mark.parametrize("filename", [
    "account_state.json",
    "challenge_rules.json",
    "funded_rules.json",
    "risk_params.json",
    "notifications.json",
    "symbols.json",
])
def test_config_is_valid_json(filename):
    """All config files must parse as valid JSON."""
    config_path = CONFIGS_DIR / filename
    assert config_path.exists(), f"Missing config file: {filename}"
    with open(config_path) as f:
        data = json.load(f)
    assert isinstance(data, dict) or isinstance(data, list)


# --- FundedNext Stellar Instant Rules ---

class TestFundedRules:
    """Verify funded_rules.json matches FundedNext Stellar Instant requirements."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.rules = load_config("funded_rules.json")

    def test_no_daily_dd_limit(self):
        """Stellar Instant has NO daily drawdown limit."""
        assert self.rules["max_daily_drawdown_percent"] == 0

    def test_trailing_dd_6_percent(self):
        """Stellar Instant has 6% trailing total drawdown."""
        assert self.rules["max_total_drawdown_percent"] == 6

    def test_trailing_dd_enabled(self):
        """DD must be trailing (from equity high water mark)."""
        assert self.rules["trailing_drawdown"] is True

    def test_ea_allowed(self):
        assert self.rules["ea_allowed"] is True

    def test_consistency_rule(self):
        """Max 40% of total profit in a single day."""
        assert self.rules["consistency_rule"]["enabled"] is True
        assert self.rules["consistency_rule"]["max_single_day_profit_percent"] == 40

    def test_account_size(self):
        assert self.rules["account_size"] == 2000

    def test_no_profit_target(self):
        """Stellar Instant has no profit target."""
        assert self.rules["has_profit_target"] is False
        assert self.rules["profit_target_percent"] == 0


# --- Risk Params Safety ---

class TestRiskParams:
    """Verify risk_params.json has safe values."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.params = load_config("risk_params.json")

    def test_risk_per_trade_safe(self):
        """Risk per trade must not exceed 1%."""
        assert self.params["risk_per_trade_percent"] <= 1.0

    def test_max_risk_capped(self):
        assert self.params["max_risk_per_trade_percent"] <= 1.0

    def test_max_positions_limited(self):
        assert self.params["max_open_positions"] <= 3

    def test_dd_guards_match_funded_rules(self):
        """DD guards must match funded_rules.json hard limits."""
        dd = self.params["drawdown_guards"]
        assert dd["hard_total_dd_percent"] == 6.0
        assert dd["trailing_drawdown"] is True

    def test_soft_below_critical_below_hard(self):
        """Safety buffer order: soft < critical < hard."""
        dd = self.params["drawdown_guards"]
        assert dd["soft_total_dd_percent"] < dd["critical_total_dd_percent"]
        assert dd["critical_total_dd_percent"] < dd["hard_total_dd_percent"]

    def test_consistency_rule_enabled(self):
        cr = self.params["consistency_rule"]
        assert cr["enabled"] is True
        assert cr["max_single_day_profit_percent"] == 40

    def test_min_rr_ratio(self):
        assert self.params["min_risk_reward_ratio"] >= 1.5


# --- Challenge Rules ---

class TestChallengeRules:
    """Verify challenge_rules.json consistency."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.rules = load_config("challenge_rules.json")

    def test_trailing_dd(self):
        assert self.rules["trailing_drawdown"] is True
        assert self.rules["max_total_drawdown_percent"] == 6

    def test_no_daily_dd(self):
        assert self.rules["max_daily_drawdown_percent"] == 0

    def test_account_size_matches(self):
        assert self.rules["account_size"] == 2000


# --- Cross-Config Consistency ---

class TestCrossConfigConsistency:
    """Verify all configs agree on critical values."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.funded = load_config("funded_rules.json")
        self.risk = load_config("risk_params.json")
        self.challenge = load_config("challenge_rules.json")
        self.account = load_config("account_state.json")

    def test_account_size_consistent(self):
        """All configs must use $2000 account size."""
        assert self.funded["account_size"] == 2000
        assert self.challenge["account_size"] == 2000
        assert self.account["funded_instant"]["account_size"] == 2000

    def test_dd_limits_consistent(self):
        """DD limits in risk_params must match funded_rules."""
        risk_dd = self.risk["drawdown_guards"]["hard_total_dd_percent"]
        funded_dd = self.funded["max_total_drawdown_percent"]
        assert risk_dd == funded_dd

    def test_trailing_dd_consistent(self):
        assert self.risk["drawdown_guards"]["trailing_drawdown"] is True
        assert self.funded["trailing_drawdown"] is True
        assert self.challenge["trailing_drawdown"] is True

    def test_consistency_rule_matches(self):
        risk_cr = self.risk["consistency_rule"]["max_single_day_profit_percent"]
        funded_cr = self.funded["consistency_rule"]["max_single_day_profit_percent"]
        assert risk_cr == funded_cr == 40


# --- Symbols Config ---

class TestSymbolsConfig:
    """Verify symbols.json has correct symbol definitions."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.config = load_config("symbols.json")
        self.symbols = {s["name"]: s for s in self.config["symbols"]}

    def test_expected_symbols_present(self):
        expected = {"EURUSD", "GBPUSD", "USDJPY", "XAUUSD"}
        assert set(self.symbols.keys()) == expected

    def test_all_symbols_enabled(self):
        for name, sym in self.symbols.items():
            assert sym["enabled"] is True, f"{name} should be enabled"

    def test_pip_sizes_correct(self):
        assert self.symbols["EURUSD"]["pip_size"] == 0.0001
        assert self.symbols["GBPUSD"]["pip_size"] == 0.0001
        assert self.symbols["USDJPY"]["pip_size"] == 0.01
        assert self.symbols["XAUUSD"]["pip_size"] == 0.01

    def test_lot_limits_safe(self):
        for name, sym in self.symbols.items():
            assert sym["min_lot"] == 0.01
            assert sym["max_lot"] <= 5.0


# --- Notifications Config ---

class TestNotificationsConfig:

    @pytest.fixture(autouse=True)
    def setup(self):
        self.config = load_config("notifications.json")

    def test_telegram_configured(self):
        tg = self.config["telegram"]
        assert tg["token"] != ""
        assert tg["chat_id"] != ""

    def test_critical_notifications_enabled(self):
        notify = self.config["notify_on"]
        assert notify["emergency"] is True
        assert notify["state_change"] is True
        assert notify["trade_close"] is True
