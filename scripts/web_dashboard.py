#!/usr/bin/env python3
"""
PropFirmBot Web Dashboard
Simple monitoring dashboard accessible from browser
Run on VPS: python3 /root/MT5-PropFirm-Bot/scripts/web_dashboard.py
Access: http://77.237.234.2:8080
"""

import http.server
import json
import os
import glob
import subprocess
import urllib.request
import urllib.parse
from datetime import datetime, timezone

PORT = 8080
MT5_DIR = "/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_LOGS_DIR = os.path.join(MT5_DIR, "MQL5", "Logs")
TERMINAL_LOGS_DIR = os.path.join(MT5_DIR, "logs")
EA_FILES_DIR = os.path.join(MT5_DIR, "MQL5", "Experts", "PropFirmBot")
CONFIG_DIR = os.path.join(MT5_DIR, "MQL5", "Files", "PropFirmBot")

# Telegram
TELEGRAM_TOKEN = "8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID = "7013213983"


def is_mt5_running():
    try:
        result = subprocess.run(["pgrep", "-f", "terminal64"],
                                capture_output=True, text=True, timeout=5)
        return result.returncode == 0
    except Exception:
        return False


def get_mt5_connections():
    try:
        result = subprocess.run(
            ["ss", "-tn", "state", "established"],
            capture_output=True, text=True, timeout=5
        )
        lines = result.stdout.strip().split('\n')
        connections = []
        for line in lines:
            if ':22 ' not in line and ':5900 ' not in line and ':53 ' not in line and ':8080' not in line:
                parts = line.split()
                if len(parts) >= 5:
                    connections.append(parts[4])
        return connections
    except Exception:
        return []


def read_log_tail(log_dir, max_lines=50):
    """Read the most recent log file's last N lines."""
    try:
        log_files = sorted(glob.glob(os.path.join(log_dir, "*.log")), reverse=True)
        if not log_files:
            return "(no log files found)", ""

        log_file = log_files[0]
        filename = os.path.basename(log_file)

        with open(log_file, 'rb') as f:
            content = f.read()
        # Remove null bytes (Wine logs have them)
        text = content.decode('utf-8', errors='replace').replace('\x00', '')
        lines = text.strip().split('\n')
        return '\n'.join(lines[-max_lines:]), filename
    except Exception as e:
        return f"(error reading logs: {e})", ""


def get_ea_file_status():
    """Check if EA files are present and compiled."""
    files = {}
    try:
        for f in glob.glob(os.path.join(EA_FILES_DIR, "*")):
            name = os.path.basename(f)
            size = os.path.getsize(f)
            mtime = datetime.fromtimestamp(os.path.getmtime(f)).strftime('%Y-%m-%d %H:%M')
            files[name] = {"size": size, "modified": mtime}
    except Exception:
        pass
    return files


def send_telegram_test():
    """Send a test message via Telegram."""
    try:
        url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
        data = urllib.parse.urlencode({
            'chat_id': TELEGRAM_CHAT_ID,
            'text': f'Dashboard test at {datetime.now(timezone.utc).strftime("%H:%M:%S UTC")}\nMT5: {"RUNNING" if is_mt5_running() else "STOPPED"}',
            'parse_mode': 'HTML'
        }).encode('utf-8')
        req = urllib.request.Request(url, data=data)
        resp = urllib.request.urlopen(req, timeout=10)
        return resp.status == 200
    except Exception as e:
        return False


def get_status_data():
    """Gather all status data."""
    mt5_running = is_mt5_running()
    connections = get_mt5_connections()
    ea_log, ea_log_file = read_log_tail(EA_LOGS_DIR, 60)
    terminal_log, term_log_file = read_log_tail(TERMINAL_LOGS_DIR, 30)
    ea_files = get_ea_file_status()

    # Check for key indicators in EA log
    has_init = "ALL SYSTEMS GO" in ea_log or "INIT" in ea_log
    has_guardian = "GUARDIAN" in ea_log
    has_trade = "TRADE" in ea_log or "BUY" in ea_log or "SELL" in ea_log
    has_error = "error" in ea_log.lower() or "failed" in ea_log.lower() or "FATAL" in ea_log
    has_signal = "signal" in ea_log.lower() or "SMC" in ea_log or "EMA" in ea_log
    has_blocked = "BLOCKED" in ea_log
    has_telegram_error = "4014" in ea_log or "WebRequest" in ea_log
    has_ex5 = "PropFirmBot.ex5" in str(ea_files)

    return {
        "timestamp": datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC'),
        "mt5_running": mt5_running,
        "connections": connections,
        "connection_count": len(connections),
        "ea_log": ea_log,
        "ea_log_file": ea_log_file,
        "terminal_log": terminal_log,
        "terminal_log_file": term_log_file,
        "ea_files": ea_files,
        "has_ex5": has_ex5,
        "has_init": has_init,
        "has_guardian": has_guardian,
        "has_trade": has_trade,
        "has_error": has_error,
        "has_signal": has_signal,
        "has_blocked": has_blocked,
        "has_telegram_error": has_telegram_error,
    }


def generate_html(data):
    """Generate the dashboard HTML page."""

    # Status indicators
    def badge(ok, text_ok, text_fail):
        if ok:
            return f'<span class="badge ok">{text_ok}</span>'
        return f'<span class="badge fail">{text_fail}</span>'

    # Build status cards
    mt5_status = badge(data["mt5_running"], "MT5 RUNNING", "MT5 STOPPED")
    conn_status = badge(data["connection_count"] > 0, f'{data["connection_count"]} connections', "NO CONNECTIONS")
    ea_status = badge(data["has_ex5"], "EA COMPILED", "EA NOT FOUND")
    init_status = badge(data["has_init"], "EA INITIALIZED", "EA NOT INITIALIZED")
    error_status = badge(not data["has_error"], "NO ERRORS", "ERRORS DETECTED!")
    trade_status = badge(data["has_trade"], "TRADES DETECTED", "NO TRADES YET")
    signal_status = badge(data["has_signal"], "SIGNALS ACTIVE", "NO SIGNALS YET")
    telegram_status = badge(not data["has_telegram_error"], "TELEGRAM OK", "TELEGRAM BLOCKED - Add WebRequest URL!")

    # EA files table
    ea_files_html = ""
    for name, info in sorted(data["ea_files"].items()):
        icon = "&#9989;" if name.endswith('.ex5') else "&#128196;"
        ea_files_html += f'<tr><td>{icon} {name}</td><td>{info["size"]:,} bytes</td><td>{info["modified"]}</td></tr>'

    # Connections
    conn_html = ""
    for c in data["connections"][:10]:
        conn_html += f"<div class='conn'>{c}</div>"

    # Escape HTML in logs
    ea_log_safe = data["ea_log"].replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    term_log_safe = data["terminal_log"].replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

    # Color-code log lines
    def colorize_log(text):
        lines = text.split('\n')
        colored = []
        for line in lines:
            if 'ERROR' in line or 'FATAL' in line or 'error' in line.lower() or 'failed' in line.lower():
                colored.append(f'<span class="log-error">{line}</span>')
            elif 'WARNING' in line or 'BLOCKED' in line:
                colored.append(f'<span class="log-warn">{line}</span>')
            elif 'TRADE' in line or 'BUY' in line or 'SELL' in line or 'CLOSED' in line:
                colored.append(f'<span class="log-trade">{line}</span>')
            elif 'INIT' in line or 'ALL SYSTEMS GO' in line:
                colored.append(f'<span class="log-init">{line}</span>')
            elif 'GUARDIAN' in line:
                colored.append(f'<span class="log-guardian">{line}</span>')
            else:
                colored.append(line)
        return '\n'.join(colored)

    ea_log_colored = colorize_log(ea_log_safe)
    term_log_colored = colorize_log(term_log_safe)

    html = f"""<!DOCTYPE html>
<html lang="he" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="30">
<title>PropFirmBot Dashboard</title>
<style>
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #0a0e1a; color: #e0e0e0; padding: 15px; }}
.header {{ text-align: center; padding: 20px; background: linear-gradient(135deg, #1a1f3a, #0d1226); border-radius: 12px; margin-bottom: 20px; border: 1px solid #2a3050; }}
.header h1 {{ color: #ffd700; font-size: 24px; margin-bottom: 5px; }}
.header .time {{ color: #888; font-size: 14px; }}
.header .refresh {{ color: #555; font-size: 12px; }}
.grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 10px; margin-bottom: 20px; }}
.card {{ background: #12172a; border-radius: 10px; padding: 15px; border: 1px solid #1e2640; text-align: center; }}
.badge {{ display: inline-block; padding: 8px 16px; border-radius: 20px; font-weight: bold; font-size: 13px; }}
.badge.ok {{ background: #0d3320; color: #4ade80; border: 1px solid #166534; }}
.badge.fail {{ background: #3b1010; color: #f87171; border: 1px solid #991b1b; animation: pulse 2s infinite; }}
@keyframes pulse {{ 0%,100% {{ opacity: 1; }} 50% {{ opacity: 0.7; }} }}
.card-label {{ font-size: 11px; color: #666; margin-top: 8px; text-transform: uppercase; }}
.section {{ background: #12172a; border-radius: 10px; padding: 15px; margin-bottom: 15px; border: 1px solid #1e2640; }}
.section h2 {{ color: #ffd700; font-size: 16px; margin-bottom: 10px; border-bottom: 1px solid #1e2640; padding-bottom: 8px; }}
.log {{ background: #080b15; padding: 12px; border-radius: 8px; font-family: 'Courier New', monospace; font-size: 11px; line-height: 1.5; max-height: 400px; overflow-y: auto; white-space: pre-wrap; word-break: break-all; direction: ltr; text-align: left; }}
.log-error {{ color: #f87171; font-weight: bold; }}
.log-warn {{ color: #fbbf24; }}
.log-trade {{ color: #4ade80; font-weight: bold; }}
.log-init {{ color: #60a5fa; }}
.log-guardian {{ color: #c084fc; }}
table {{ width: 100%; border-collapse: collapse; direction: ltr; text-align: left; }}
th {{ background: #1a1f3a; padding: 8px; font-size: 12px; color: #888; }}
td {{ padding: 6px 8px; font-size: 12px; border-bottom: 1px solid #1e2640; }}
.conn {{ display: inline-block; background: #1a2040; padding: 3px 8px; border-radius: 4px; margin: 2px; font-size: 11px; font-family: monospace; direction: ltr; }}
.btn {{ display: inline-block; padding: 10px 25px; background: #2563eb; color: white; border: none; border-radius: 8px; font-size: 14px; cursor: pointer; text-decoration: none; margin: 5px; }}
.btn:hover {{ background: #1d4ed8; }}
.btn-warn {{ background: #dc2626; }}
.btn-warn:hover {{ background: #b91c1c; }}
.actions {{ text-align: center; margin: 20px 0; }}
</style>
</head>
<body>

<div class="header">
    <h1>PropFirmBot Dashboard</h1>
    <div class="time">{data["timestamp"]}</div>
    <div class="refresh">Auto-refresh every 30 seconds</div>
</div>

<div class="grid">
    <div class="card">{mt5_status}<div class="card-label">MetaTrader 5</div></div>
    <div class="card">{conn_status}<div class="card-label">Broker Connection</div></div>
    <div class="card">{ea_status}<div class="card-label">EA Compiled</div></div>
    <div class="card">{init_status}<div class="card-label">EA Status</div></div>
    <div class="card">{error_status}<div class="card-label">Errors</div></div>
    <div class="card">{trade_status}<div class="card-label">Trading</div></div>
    <div class="card">{signal_status}<div class="card-label">Signals</div></div>
    <div class="card">{telegram_status}<div class="card-label">Telegram</div></div>
</div>

<div class="actions">
    <a href="/telegram_test" class="btn">Test Telegram</a>
    <a href="/" class="btn">Refresh</a>
</div>

<div class="section">
    <h2>EA Log ({data["ea_log_file"]})</h2>
    <div class="log">{ea_log_colored}</div>
</div>

<div class="section">
    <h2>Terminal Log ({data["terminal_log_file"]})</h2>
    <div class="log">{term_log_colored}</div>
</div>

<div class="section">
    <h2>EA Files</h2>
    <table>
        <tr><th>File</th><th>Size</th><th>Modified</th></tr>
        {ea_files_html}
    </table>
</div>

<div class="section">
    <h2>Network Connections</h2>
    {conn_html if conn_html else '<div style="color:#666">No broker connections detected</div>'}
</div>

</body>
</html>"""
    return html


class DashboardHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/telegram_test':
            success = send_telegram_test()
            self.send_response(302)
            self.send_header('Location', '/')
            self.end_headers()
            return

        if self.path == '/api/status':
            data = get_status_data()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            # Remove large log data for API
            api_data = {k: v for k, v in data.items() if k not in ('ea_log', 'terminal_log')}
            self.wfile.write(json.dumps(api_data, indent=2).encode())
            return

        data = get_status_data()
        html = generate_html(data)

        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.end_headers()
        self.wfile.write(html.encode('utf-8'))

    def log_message(self, format, *args):
        pass  # Suppress request logging


def main():
    print(f"PropFirmBot Dashboard starting on port {PORT}...")
    print(f"Access: http://77.237.234.2:{PORT}")
    server = http.server.HTTPServer(('0.0.0.0', PORT), DashboardHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nDashboard stopped.")
        server.server_close()


if __name__ == '__main__':
    main()
