#!/usr/bin/env python3
"""
MT5 Status Daemon
Reads EA status.json + journal CSVs and writes combined data to /var/bots/mt5_status.json
Runs as a systemd service, updates every 5 seconds.
"""

import os
import sys
import json
import csv
import time
import glob
from datetime import datetime, timedelta

# Paths
MT5_FILES_DIR = os.environ.get(
    'MT5_FILES_DIR',
    '/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files'
)
STATUS_JSON = os.path.join(MT5_FILES_DIR, 'PropFirmBot', 'status.json')
OUTPUT_FILE = '/var/bots/mt5_status.json'
UPDATE_INTERVAL = 5  # seconds


def read_ea_status():
    """Read the real-time status.json written by the EA."""
    try:
        mtime = os.path.getmtime(STATUS_JSON)
        with open(STATUS_JSON, 'r', encoding='utf-8') as f:
            data = json.load(f)
        data['_file_age_seconds'] = round(time.time() - mtime, 1)
        data['_is_stale'] = (time.time() - mtime) > 30
        return data
    except FileNotFoundError:
        return None
    except (json.JSONDecodeError, Exception) as e:
        print(f"[WARN] Error reading status.json: {e}", file=sys.stderr)
        return None


def parse_open_positions(ea_status):
    """Extract open positions from EA status in simplified format."""
    if not ea_status:
        return [], 0

    positions_data = ea_status.get('positions', {})
    raw_positions = positions_data.get('open', [])
    count = positions_data.get('count', 0)

    simplified = []
    for pos in raw_positions:
        simplified.append({
            'symbol': pos.get('symbol', ''),
            'direction': pos.get('type', ''),       # BUY / SELL
            'profit': pos.get('profit', 0.0),        # current P&L in $
            'volume': pos.get('volume', 0.0),
            'open_price': pos.get('open_price', 0.0),
            'current_price': pos.get('current_price', 0.0),
            'pips': pos.get('pips', 0.0),
            'ticket': pos.get('ticket', 0),
            'open_time': pos.get('open_time', ''),
        })

    return simplified, count


def get_last_closed_trades(n=5):
    """Read journal CSVs and return the last N closed trades."""
    closed = []
    today = datetime.now()

    # Search last 30 days of journal files
    for d in range(30):
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
                    row = [cell.strip() for cell in row]
                    if header is None:
                        header = row
                        continue

                    record = {}
                    for i, col in enumerate(header):
                        if i < len(row):
                            record[col.strip()] = row[i]

                    if record.get('Type') == 'CLOSE':
                        pnl_str = record.get('PnL', '0')
                        try:
                            pnl = float(pnl_str)
                        except (ValueError, TypeError):
                            pnl = 0.0

                        closed.append({
                            'symbol': record.get('Symbol', ''),
                            'profit': pnl,
                            'close_time': record.get('DateTime', ''),
                            'direction': record.get('Direction', ''),
                            'pnl_pips': record.get('PnL_Pips', ''),
                            'ticket': record.get('Ticket', ''),
                        })
        except Exception as e:
            print(f"[WARN] Error reading {filepath}: {e}", file=sys.stderr)

    # Sort by close_time descending, return last N
    closed.sort(key=lambda x: x.get('close_time', ''), reverse=True)
    return closed[:n]


def build_status():
    """Build the combined status JSON."""
    ea_status = read_ea_status()
    open_positions, open_count = parse_open_positions(ea_status)
    last_closed = get_last_closed_trades(5)

    result = {
        'updated_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'ea_connected': ea_status is not None and not ea_status.get('_is_stale', True),
    }

    # Account info from EA
    if ea_status:
        account = ea_status.get('account', {})
        result['account'] = {
            'balance': account.get('balance', 0),
            'equity': account.get('equity', 0),
            'floating_pnl': account.get('floating_pnl', 0),
            'margin': account.get('margin', 0),
            'free_margin': account.get('free_margin', 0),
        }
        guardian = ea_status.get('guardian', {})
        result['guardian_state'] = guardian.get('state', 'UNKNOWN')
        result['daily_dd'] = guardian.get('daily_dd', 0)
        result['total_dd'] = guardian.get('total_dd', 0)

        today = ea_status.get('today', {})
        result['today'] = {
            'trades': today.get('trades', 0),
            'wins': today.get('wins', 0),
            'losses': today.get('losses', 0),
            'net': today.get('net', 0),
        }

    # Open positions
    result['open_positions'] = {
        'count': open_count,
        'trades': open_positions,
    }

    # Last 5 closed trades
    result['last_closed'] = last_closed

    return result


def write_status(data):
    """Write status JSON to output file."""
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    tmp_file = OUTPUT_FILE + '.tmp'
    try:
        with open(tmp_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        os.replace(tmp_file, OUTPUT_FILE)
    except Exception as e:
        print(f"[ERROR] Cannot write {OUTPUT_FILE}: {e}", file=sys.stderr)
        # Cleanup tmp if it exists
        try:
            os.remove(tmp_file)
        except OSError:
            pass


def main():
    print(f"MT5 Status Daemon started")
    print(f"  Reading from: {STATUS_JSON}")
    print(f"  Journal dir:  {MT5_FILES_DIR}")
    print(f"  Writing to:   {OUTPUT_FILE}")
    print(f"  Interval:     {UPDATE_INTERVAL}s")

    while True:
        try:
            data = build_status()
            write_status(data)
        except Exception as e:
            print(f"[ERROR] {e}", file=sys.stderr)

        time.sleep(UPDATE_INTERVAL)


if __name__ == '__main__':
    main()
