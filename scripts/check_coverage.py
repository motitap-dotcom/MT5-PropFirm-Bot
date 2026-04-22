#!/usr/bin/env python3
"""Enforce per-module coverage floors for safety-critical modules.

Reads coverage.json (produced by `coverage json`) and fails with a clear
message if any of the listed modules drops below its floor. This protects
against silent regressions in TradeDay rule enforcement, position sizing,
and strategy math.

Raise the floors as coverage improves — never lower them.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

# (relative path, minimum percent). Only modules that contain rule
# enforcement or strategy math — NOT network, I/O, or orchestration.
FLOORS = {
    # Safety-critical rule enforcement and strategy math — must stay very high.
    "futures_bot/core/guardian.py":                   95.0,
    "futures_bot/core/risk_manager.py":               94.0,
    "futures_bot/core/news_filter.py":                87.0,
    "futures_bot/strategies/orb_breakout.py":        100.0,
    "futures_bot/strategies/vwap_mean_reversion.py":  95.0,
    "futures_bot/core/status_writer.py":              88.0,
    # Messaging + orchestration — moderate floor; network paths excluded.
    "futures_bot/core/notifier.py":                   88.0,
    "futures_bot/bot.py":                             50.0,
    # Tradovate REST/WS client — pure functions + renew logic only.
    "futures_bot/core/tradovate_client.py":           32.0,
}


def main(report_path: str = "coverage.json") -> int:
    p = Path(report_path)
    if not p.exists():
        print(f"ERROR: {p} not found. Run `coverage json` first.", file=sys.stderr)
        return 2

    data = json.loads(p.read_text())
    files = data.get("files", {})
    failures = []

    for rel, floor in FLOORS.items():
        entry = files.get(rel)
        if entry is None:
            failures.append(f"{rel}: not found in coverage report")
            continue
        pct = entry["summary"]["percent_covered"]
        if pct < floor:
            failures.append(f"{rel}: {pct:.1f}% < floor {floor:.1f}%")
        else:
            print(f"  OK   {rel}: {pct:.1f}% (floor {floor:.1f}%)")

    if failures:
        print("\nCoverage floor violations:", file=sys.stderr)
        for f in failures:
            print(f"  FAIL {f}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
