#!/usr/bin/env python3
"""
PropFirmBot Web Dashboard Server
Reads MT5 data files and serves a real-time trading dashboard.
No external dependencies - uses only Python standard library.
"""

import os
import sys
import json
import csv
import glob
import time
import threading
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
from datetime import datetime, timedelta

# Configuration
PORT = 8081
MT5_FILES_DIR = os.environ.get(
    'MT5_FILES_DIR',
    '/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files'
)
PROPFIRMBOT_DIR = os.path.join(MT5_FILES_DIR, 'PropFirmBot')
DASHBOARD_DIR = os.path.dirname(os.path.abspath(__file__))

# Cache for file reads
_cache = {}
_cache_ttl = 2  # seconds


def read_status_json():
    """Read the real-time status.json written by the EA."""
    filepath = os.path.join(PROPFIRMBOT_DIR, 'status.json')
    try:
        mtime = os.path.getmtime(filepath)
        if filepath in _cache and _cache[filepath]['mtime'] == mtime:
            return _cache[filepath]['data']

        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)

        # Add staleness indicator
        file_age = time.time() - mtime
        data['_file_age_seconds'] = round(file_age, 1)
        data['_is_stale'] = file_age > 30  # Stale if older than 30 sec

        _cache[filepath] = {'mtime': mtime, 'data': data}
        return data
    except FileNotFoundError:
        return {'error': 'status.json not found - EA may not be running',
                '_is_stale': True}
    except json.JSONDecodeError as e:
        return {'error': f'Invalid JSON in status.json: {e}',
                '_is_stale': True}
    except Exception as e:
        return {'error': str(e), '_is_stale': True}


def read_journal_csv(days=30):
    """Read trade journal CSV files from the last N days."""
    trades = []
    today = datetime.now()

    for d in range(days):
        date = today - timedelta(days=d)
        date_str = date.strftime('%Y%m%d')
        filepath = os.path.join(MT5_FILES_DIR,
                                f'PropFirmBot_Journal_{date_str}.csv')
        if not os.path.exists(filepath):
            continue

        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                reader = csv.reader(f)
                header = None
                for row in reader:
                    if not row:
                        continue
                    # Clean whitespace
                    row = [cell.strip() for cell in row]

                    if header is None:
                        header = row
                        continue

                    record = {}
                    for i, col in enumerate(header):
                        col = col.strip()
                        if i < len(row):
                            record[col] = row[i]

                    trades.append(record)
        except Exception as e:
            print(f"Error reading {filepath}: {e}")

    return trades


def read_analysis_csv():
    """Read the performance analysis CSV."""
    filepath = os.path.join(MT5_FILES_DIR, 'PropFirmBot_Analysis.csv')
    analysis = {'overall': {}, 'symbols': [], 'strategies': []}

    if not os.path.exists(filepath):
        return analysis

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            reader = csv.reader(f)
            header = None
            for row in reader:
                if not row:
                    continue
                row = [cell.strip() for cell in row]

                if header is None:
                    header = row
                    continue

                record = {}
                for i, col in enumerate(header):
                    col = col.strip()
                    if i < len(row):
                        record[col] = row[i]

                row_type = record.get('Type', '')
                if row_type == 'OVERALL':
                    analysis['overall'] = record
                elif row_type == 'SYMBOL':
                    analysis['symbols'].append(record)
                elif row_type == 'STRATEGY':
                    analysis['strategies'].append(record)
    except Exception as e:
        print(f"Error reading analysis: {e}")

    return analysis


def get_trade_history():
    """Parse journal into structured trade history."""
    all_records = read_journal_csv(30)

    open_trades = {}
    closed_trades = []
    events = []

    for record in all_records:
        rec_type = record.get('Type', '')

        if rec_type == 'OPEN':
            ticket = record.get('Ticket', '')
            open_trades[ticket] = record

        elif rec_type == 'CLOSE':
            ticket = record.get('Ticket', '')
            entry = open_trades.pop(ticket, {})
            closed_trades.append({
                'ticket': ticket,
                'symbol': record.get('Symbol', ''),
                'direction': record.get('Direction', ''),
                'lot': record.get('Lot', ''),
                'entry_price': entry.get('EntryPrice', record.get('EntryPrice', '')),
                'exit_price': record.get('ExitPrice', ''),
                'sl': record.get('SL', ''),
                'tp': record.get('TP', ''),
                'pnl': record.get('PnL', ''),
                'pnl_pips': record.get('PnL_Pips', ''),
                'strategy': entry.get('Strategy', record.get('Strategy', '')),
                'reason': record.get('Reason', ''),
                'open_time': entry.get('DateTime', ''),
                'close_time': record.get('DateTime', ''),
                'balance': record.get('Balance', ''),
            })

        elif rec_type in ('INIT', 'SHUTDOWN', 'STARTUP', 'STATE_CHANGE',
                          'HALTED', 'EMERGENCY', 'ANALYSIS', 'EVENT'):
            events.append({
                'time': record.get('DateTime', ''),
                'type': rec_type,
                'message': record.get('Message', ''),
                'balance': record.get('Balance', ''),
                'equity': record.get('Equity', ''),
            })
        # Some events use a non-standard type
        elif rec_type not in ('OPEN', 'CLOSE') and rec_type != '':
            events.append({
                'time': record.get('DateTime', ''),
                'type': rec_type,
                'message': record.get('Message', ''),
                'balance': record.get('Balance', ''),
                'equity': record.get('Equity', ''),
            })

    # Sort closed trades: most recent first
    closed_trades.sort(key=lambda x: x.get('close_time', ''), reverse=True)

    return {
        'closed': closed_trades,
        'events': events[-50:],  # Last 50 events
        'total_closed': len(closed_trades),
    }


def calculate_stats(trades):
    """Calculate performance statistics from closed trades."""
    if not trades:
        return {
            'total': 0, 'wins': 0, 'losses': 0, 'win_rate': 0,
            'total_pnl': 0, 'avg_win': 0, 'avg_loss': 0,
            'profit_factor': 0, 'best_trade': 0, 'worst_trade': 0,
            'by_symbol': {}, 'by_day': [],
        }

    wins = []
    losses = []
    by_symbol = {}
    by_day = {}

    for t in trades:
        try:
            pnl = float(t.get('pnl', 0))
        except (ValueError, TypeError):
            continue

        if pnl >= 0:
            wins.append(pnl)
        else:
            losses.append(pnl)

        # By symbol
        sym = t.get('symbol', 'Unknown')
        if sym not in by_symbol:
            by_symbol[sym] = {'wins': 0, 'losses': 0, 'pnl': 0, 'trades': 0}
        by_symbol[sym]['trades'] += 1
        by_symbol[sym]['pnl'] += pnl
        if pnl >= 0:
            by_symbol[sym]['wins'] += 1
        else:
            by_symbol[sym]['losses'] += 1

        # By day
        day = t.get('close_time', '')[:10]
        if day:
            if day not in by_day:
                by_day[day] = {'pnl': 0, 'trades': 0, 'wins': 0, 'losses': 0}
            by_day[day]['trades'] += 1
            by_day[day]['pnl'] += pnl
            if pnl >= 0:
                by_day[day]['wins'] += 1
            else:
                by_day[day]['losses'] += 1

    total = len(wins) + len(losses)
    gross_profit = sum(wins) if wins else 0
    gross_loss = abs(sum(losses)) if losses else 0

    # Daily PnL sorted by date
    daily_pnl = [{'date': d, **v} for d, v in sorted(by_day.items())]

    return {
        'total': total,
        'wins': len(wins),
        'losses': len(losses),
        'win_rate': round(len(wins) / total * 100, 1) if total > 0 else 0,
        'total_pnl': round(gross_profit - gross_loss, 2),
        'gross_profit': round(gross_profit, 2),
        'gross_loss': round(gross_loss, 2),
        'avg_win': round(gross_profit / len(wins), 2) if wins else 0,
        'avg_loss': round(gross_loss / len(losses), 2) if losses else 0,
        'profit_factor': round(gross_profit / gross_loss, 2) if gross_loss > 0 else 999,
        'best_trade': round(max(wins), 2) if wins else 0,
        'worst_trade': round(min(losses), 2) if losses else 0,
        'by_symbol': by_symbol,
        'daily_pnl': daily_pnl,
    }


class DashboardHandler(SimpleHTTPRequestHandler):
    """HTTP request handler for the dashboard."""

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path == '/' or path == '/index.html':
            self.serve_html()
        elif path == '/api/status':
            self.serve_json(read_status_json())
        elif path == '/api/trades':
            history = get_trade_history()
            stats = calculate_stats(history['closed'])
            self.serve_json({**history, 'stats': stats})
        elif path == '/api/analysis':
            self.serve_json(read_analysis_csv())
        elif path == '/api/health':
            self.serve_json({
                'status': 'ok',
                'time': datetime.now().isoformat(),
                'mt5_files_dir': MT5_FILES_DIR,
                'status_file_exists': os.path.exists(
                    os.path.join(PROPFIRMBOT_DIR, 'status.json')),
            })
        else:
            # Serve static files from dashboard dir
            self.directory = DASHBOARD_DIR
            super().do_GET()

    def serve_html(self):
        html_path = os.path.join(DASHBOARD_DIR, 'index.html')
        try:
            with open(html_path, 'r', encoding='utf-8') as f:
                content = f.read()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(content.encode('utf-8'))
        except FileNotFoundError:
            self.send_error(404, 'index.html not found')

    def serve_json(self, data):
        content = json.dumps(data, ensure_ascii=False, default=str)
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Cache-Control', 'no-cache')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(content.encode('utf-8'))

    def log_message(self, format, *args):
        # Quieter logging - only errors
        if '404' in str(args) or '500' in str(args):
            super().log_message(format, *args)


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else PORT

    print(f"==========================================")
    print(f"  PropFirmBot Web Dashboard")
    print(f"  Port: {port}")
    print(f"  MT5 Files: {MT5_FILES_DIR}")
    print(f"  Status file: {os.path.join(PROPFIRMBOT_DIR, 'status.json')}")
    print(f"==========================================")
    print(f"  Open in browser: http://localhost:{port}")
    print(f"==========================================")

    server = HTTPServer(('0.0.0.0', port), DashboardHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down dashboard server...")
        server.shutdown()


if __name__ == '__main__':
    main()
