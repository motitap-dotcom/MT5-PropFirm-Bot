"""
PropFirmBot - Automated Daily & Weekly Performance Reports
==========================================================
Generates detailed reports with charts and sends them via Telegram.

Schedule this script to run daily at market close (e.g., 17:00 UTC)
and weekly on Friday evening.

Usage:
    python daily_report.py --daily          # Generate daily report
    python daily_report.py --weekly         # Generate weekly report
    python daily_report.py --telegram       # Send latest report via Telegram
    python daily_report.py --all            # Generate + send
"""

import os
import sys
import json
import argparse
from datetime import datetime, timedelta
from pathlib import Path
from collections import defaultdict

import numpy as np
import pandas as pd

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import matplotlib.dates as mdates
    HAS_MATPLOTLIB = True
except ImportError:
    HAS_MATPLOTLIB = False

try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False


# Paths
PROJECT_DIR = Path(__file__).parent.parent
OUTPUT_DIR = PROJECT_DIR / "backtest_results" / "reports"
CONFIG_DIR = PROJECT_DIR / "configs"
MT5_COMMON_DIR = os.environ.get(
    "MT5_COMMON_DIR",
    os.path.expanduser("~/.wine/drive_c/users/Public/Documents/MetaTrader 5/Terminal/Common/Files")
)


class ReportGenerator:
    """Generates daily and weekly performance reports."""

    def __init__(self):
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        self.trades = pd.DataFrame()
        self.config = self._load_config()

    def _load_config(self):
        """Load notification config."""
        config_file = CONFIG_DIR / "notifications.json"
        if config_file.exists():
            with open(config_file) as f:
                return json.load(f)
        return {
            "telegram_token": "",
            "telegram_chat_id": "",
            "enabled": False
        }

    def load_trades(self, days_back=7):
        """Load trade data from journal CSVs."""
        all_trades = []

        # Check MT5 common files
        journal_dir = Path(MT5_COMMON_DIR)
        for pattern in ["PropFirmBot_Journal_*.csv"]:
            for f in journal_dir.glob(pattern):
                try:
                    df = pd.read_csv(f)
                    all_trades.append(df)
                except Exception:
                    pass

        # Check local logs
        for f in (PROJECT_DIR / "logs").glob("PropFirmBot_Journal_*.csv"):
            try:
                df = pd.read_csv(f)
                all_trades.append(df)
            except Exception:
                pass

        if not all_trades:
            return False

        self.trades = pd.concat(all_trades, ignore_index=True)

        # Filter closed trades
        if "Type" in self.trades.columns:
            self.trades = self.trades[self.trades["Type"] == "CLOSE"].copy()

        # Parse dates
        if "DateTime" in self.trades.columns:
            self.trades["DateTime"] = pd.to_datetime(self.trades["DateTime"], errors="coerce")
            cutoff = datetime.now() - timedelta(days=days_back)
            self.trades = self.trades[self.trades["DateTime"] >= cutoff]

        # Ensure numeric PnL
        if "PnL" in self.trades.columns:
            self.trades["PnL"] = pd.to_numeric(self.trades["PnL"], errors="coerce")

        return len(self.trades) > 0

    def generate_daily_report(self):
        """Generate a daily performance report."""
        today = datetime.now().date()
        today_trades = self.trades[
            self.trades["DateTime"].dt.date == today
        ] if not self.trades.empty else pd.DataFrame()

        report = {
            "type": "DAILY",
            "date": str(today),
            "generated_at": datetime.now().isoformat(),
        }

        if today_trades.empty:
            report["message"] = "No trades today"
            report["trades"] = 0
            return report

        pnl = today_trades["PnL"].dropna()

        report.update({
            "trades": len(pnl),
            "wins": int((pnl > 0).sum()),
            "losses": int((pnl <= 0).sum()),
            "win_rate": round(float((pnl > 0).sum() / len(pnl) * 100), 1) if len(pnl) > 0 else 0,
            "total_pnl": round(float(pnl.sum()), 2),
            "avg_pnl": round(float(pnl.mean()), 2) if len(pnl) > 0 else 0,
            "best_trade": round(float(pnl.max()), 2) if len(pnl) > 0 else 0,
            "worst_trade": round(float(pnl.min()), 2) if len(pnl) > 0 else 0,
            "profit_factor": round(
                float(pnl[pnl > 0].sum()) / abs(float(pnl[pnl <= 0].sum()))
                if pnl[pnl <= 0].sum() != 0
                else (999.0 if float(pnl[pnl > 0].sum()) > 0 else 0), 2
            ),
        })

        # Per symbol breakdown
        if "Symbol" in today_trades.columns:
            symbols = {}
            for sym in today_trades["Symbol"].unique():
                if pd.isna(sym):
                    continue
                sym_pnl = today_trades[today_trades["Symbol"] == sym]["PnL"].dropna()
                symbols[sym] = {
                    "trades": len(sym_pnl),
                    "pnl": round(float(sym_pnl.sum()), 2),
                    "win_rate": round(float((sym_pnl > 0).sum() / len(sym_pnl) * 100), 1)
                    if len(sym_pnl) > 0 else 0
                }
            report["symbols"] = symbols

        return report

    def generate_weekly_report(self):
        """Generate a weekly performance report."""
        now = datetime.now()
        week_start = now - timedelta(days=now.weekday())

        week_trades = self.trades[
            self.trades["DateTime"] >= week_start
        ] if not self.trades.empty else pd.DataFrame()

        report = {
            "type": "WEEKLY",
            "week_start": str(week_start.date()),
            "week_end": str(now.date()),
            "generated_at": now.isoformat(),
        }

        if week_trades.empty:
            report["message"] = "No trades this week"
            report["trades"] = 0
            return report

        pnl = week_trades["PnL"].dropna()

        report.update({
            "trades": len(pnl),
            "wins": int((pnl > 0).sum()),
            "losses": int((pnl <= 0).sum()),
            "win_rate": round(float((pnl > 0).sum() / len(pnl) * 100), 1) if len(pnl) > 0 else 0,
            "total_pnl": round(float(pnl.sum()), 2),
            "avg_pnl": round(float(pnl.mean()), 2) if len(pnl) > 0 else 0,
            "best_day": None,
            "worst_day": None,
            "trading_days": 0,
        })

        # Daily breakdown
        daily_pnl = week_trades.groupby(week_trades["DateTime"].dt.date)["PnL"].sum()
        report["trading_days"] = len(daily_pnl)

        if len(daily_pnl) > 0:
            report["best_day"] = {
                "date": str(daily_pnl.idxmax()),
                "pnl": round(float(daily_pnl.max()), 2)
            }
            report["worst_day"] = {
                "date": str(daily_pnl.idxmin()),
                "pnl": round(float(daily_pnl.min()), 2)
            }

        # Equity curve
        report["daily_pnl"] = {str(k): round(float(v), 2) for k, v in daily_pnl.items()}

        return report

    def generate_equity_chart(self, filename="equity_curve.png"):
        """Generate equity curve chart."""
        if not HAS_MATPLOTLIB or self.trades.empty:
            return None

        pnl = self.trades.sort_values("DateTime")
        cumulative = pnl["PnL"].cumsum()

        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 8), gridspec_kw={"height_ratios": [3, 1]})

        # Equity curve
        ax1.plot(pnl["DateTime"], cumulative, color="#00C853", linewidth=2)
        ax1.fill_between(pnl["DateTime"], cumulative, alpha=0.15, color="#00C853")
        ax1.axhline(y=0, color="white", alpha=0.3, linestyle="--")
        ax1.set_title("PropFirmBot - Equity Curve", fontsize=14, fontweight="bold", color="white")
        ax1.set_ylabel("Cumulative PnL ($)", color="white")
        ax1.set_facecolor("#1a1a2e")
        ax1.tick_params(colors="white")
        ax1.grid(True, alpha=0.2)

        # PnL per trade
        colors = ["#00C853" if p > 0 else "#FF1744" for p in pnl["PnL"]]
        ax2.bar(range(len(pnl)), pnl["PnL"], color=colors, alpha=0.8)
        ax2.axhline(y=0, color="white", alpha=0.3, linestyle="--")
        ax2.set_xlabel("Trade #", color="white")
        ax2.set_ylabel("PnL ($)", color="white")
        ax2.set_facecolor("#1a1a2e")
        ax2.tick_params(colors="white")
        ax2.grid(True, alpha=0.2)

        fig.patch.set_facecolor("#0f0f23")
        plt.tight_layout()

        filepath = OUTPUT_DIR / filename
        plt.savefig(filepath, dpi=150, bbox_inches="tight", facecolor="#0f0f23")
        plt.close()

        return str(filepath)

    def format_telegram_daily(self, report):
        """Format daily report for Telegram."""
        if report.get("trades", 0) == 0:
            return f"📊 <b>Daily Report - {report['date']}</b>\nNo trades today."

        emoji = "📈" if report["total_pnl"] >= 0 else "📉"

        msg = (
            f"{emoji} <b>Daily Report - {report['date']}</b>\n"
            f"━━━━━━━━━━━━━━━━━━━\n"
            f"Trades: {report['trades']} (W{report['wins']} L{report['losses']})\n"
            f"Win Rate: {report['win_rate']}%\n"
            f"Total PnL: <b>${report['total_pnl']:+.2f}</b>\n"
            f"Avg PnL: ${report['avg_pnl']:+.2f}\n"
            f"Best: ${report['best_trade']:+.2f} | Worst: ${report['worst_trade']:+.2f}\n"
            f"PF: {report['profit_factor']}\n"
        )

        # Symbol breakdown
        if "symbols" in report:
            msg += "\n<b>Per Symbol:</b>\n"
            for sym, data in report["symbols"].items():
                sym_emoji = "✅" if data["pnl"] >= 0 else "❌"
                msg += f"  {sym_emoji} {sym}: ${data['pnl']:+.2f} ({data['trades']}t, {data['win_rate']}%)\n"

        return msg

    def format_telegram_weekly(self, report):
        """Format weekly report for Telegram."""
        if report.get("trades", 0) == 0:
            return f"📊 <b>Weekly Report</b>\nNo trades this week."

        emoji = "📈" if report["total_pnl"] >= 0 else "📉"

        msg = (
            f"{emoji} <b>Weekly Report</b>\n"
            f"<i>{report['week_start']} to {report['week_end']}</i>\n"
            f"━━━━━━━━━━━━━━━━━━━\n"
            f"Trading Days: {report['trading_days']}\n"
            f"Total Trades: {report['trades']} (W{report['wins']} L{report['losses']})\n"
            f"Win Rate: {report['win_rate']}%\n"
            f"Total PnL: <b>${report['total_pnl']:+.2f}</b>\n"
            f"Avg PnL/Trade: ${report['avg_pnl']:+.2f}\n"
        )

        if report.get("best_day"):
            msg += f"\nBest Day: {report['best_day']['date']} (${report['best_day']['pnl']:+.2f})\n"
        if report.get("worst_day"):
            msg += f"Worst Day: {report['worst_day']['date']} (${report['worst_day']['pnl']:+.2f})\n"

        # Daily breakdown
        if "daily_pnl" in report:
            msg += "\n<b>Daily PnL:</b>\n"
            for date, pnl in report["daily_pnl"].items():
                day_emoji = "🟢" if pnl >= 0 else "🔴"
                msg += f"  {day_emoji} {date}: ${pnl:+.2f}\n"

        return msg

    def send_telegram(self, message, image_path=None):
        """Send a message via Telegram."""
        if not HAS_REQUESTS:
            print("'requests' package not installed. Cannot send Telegram messages.")
            return False

        tg = self.config.get("telegram", {})
        token = tg.get("token", "") or self.config.get("telegram_token", "")
        chat_id = tg.get("chat_id", "") or self.config.get("telegram_chat_id", "")

        if not token or not chat_id:
            print("Telegram not configured. Set token and chat_id in configs/notifications.json")
            return False

        # Send text message
        url = f"https://api.telegram.org/bot{token}/sendMessage"
        data = {
            "chat_id": chat_id,
            "text": message,
            "parse_mode": "HTML"
        }

        try:
            resp = requests.post(url, data=data, timeout=10)
            if resp.status_code != 200:
                print(f"Telegram error: {resp.text}")
                return False
        except Exception as e:
            print(f"Telegram send failed: {e}")
            return False

        # Send image if provided
        if image_path and os.path.exists(image_path):
            url = f"https://api.telegram.org/bot{token}/sendPhoto"
            with open(image_path, "rb") as photo:
                try:
                    requests.post(url, data={"chat_id": chat_id},
                                  files={"photo": photo}, timeout=30)
                except Exception:
                    pass

        return True

    def save_report(self, report, filename=None):
        """Save report as JSON."""
        if filename is None:
            filename = f"report_{report['type'].lower()}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"

        filepath = OUTPUT_DIR / filename
        with open(filepath, "w") as f:
            json.dump(report, f, indent=2, default=str)

        print(f"Report saved to {filepath}")
        return str(filepath)


def main():
    parser = argparse.ArgumentParser(description="PropFirmBot Report Generator")
    parser.add_argument("--daily", action="store_true", help="Generate daily report")
    parser.add_argument("--weekly", action="store_true", help="Generate weekly report")
    parser.add_argument("--telegram", action="store_true", help="Send via Telegram")
    parser.add_argument("--chart", action="store_true", help="Generate equity chart")
    parser.add_argument("--all", action="store_true", help="Do everything")
    args = parser.parse_args()

    if not any([args.daily, args.weekly, args.telegram, args.chart, args.all]):
        args.all = True

    gen = ReportGenerator()

    if not gen.load_trades(days_back=7):
        print("No trade data available.")
        print("Reports will be generated once the bot starts trading.")
        return

    if args.daily or args.all:
        report = gen.generate_daily_report()
        gen.save_report(report)
        print("\n--- DAILY REPORT ---")
        print(json.dumps(report, indent=2, default=str))

        if args.telegram or args.all:
            msg = gen.format_telegram_daily(report)
            gen.send_telegram(msg)

    if args.weekly or args.all:
        report = gen.generate_weekly_report()
        gen.save_report(report)
        print("\n--- WEEKLY REPORT ---")
        print(json.dumps(report, indent=2, default=str))

        if args.telegram or args.all:
            msg = gen.format_telegram_weekly(report)
            gen.send_telegram(msg)

    if args.chart or args.all:
        chart_path = gen.generate_equity_chart()
        if chart_path:
            print(f"Chart saved to {chart_path}")
            if args.telegram or args.all:
                gen.send_telegram("📊 Equity Curve", chart_path)


if __name__ == "__main__":
    main()
