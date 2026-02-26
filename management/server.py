#!/usr/bin/env python3
"""
PropFirmBot VPS Management API
===============================
Lightweight HTTP API for remote VPS management.
No external dependencies - uses Python standard library only.

Run: python3 /root/MT5-PropFirm-Bot/management/server.py
Or install as systemd service via install.sh

Endpoints (all require ?token=AUTH_TOKEN):
  GET /api/status          - Full system status (MT5, EA, VNC, account)
  GET /api/health          - Quick health check
  GET /api/positions       - Open trading positions
  GET /api/logs            - Recent EA/MT5 logs
  GET /api/logs?source=terminal&lines=100
  GET /api/account         - Account balance, equity, drawdown
  GET /api/processes       - Running processes (MT5, VNC, Wine)
  GET /api/system          - VPS system info (CPU, RAM, disk)
  GET /api/ea-status       - EA status from status.json
  GET /api/config          - Current risk/trading config
  GET /api/journal         - Recent trade journal entries

  POST /api/restart-mt5    - Restart MetaTrader 5
  POST /api/restart-vnc    - Restart VNC server
  POST /api/deploy         - Git pull + deploy EA files to MT5
  POST /api/start-mt5      - Start MT5 (if not running)
  POST /api/stop-mt5       - Stop MT5
  POST /api/telegram-test  - Send test message via Telegram
  POST /api/exec           - Execute whitelisted command
"""

import os
import sys
import json
import time
import subprocess
import threading
import hashlib
import secrets
import signal
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
from datetime import datetime, timezone
from pathlib import Path

# ─── Configuration ───────────────────────────────────────────────────────────

PORT = 8888
AUTH_TOKEN = "pfbot_mgmt_7x9Kp2mW4vQr8sNj"  # Change on first install
BIND_ADDRESS = "0.0.0.0"

MT5_DIR = "/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR = os.path.join(MT5_DIR, "MQL5", "Experts", "PropFirmBot")
CONFIG_DIR = os.path.join(MT5_DIR, "MQL5", "Files", "PropFirmBot")
EA_LOGS_DIR = os.path.join(MT5_DIR, "MQL5", "Logs")
TERMINAL_LOGS_DIR = os.path.join(MT5_DIR, "logs")
REPO_DIR = "/root/MT5-PropFirm-Bot"

TELEGRAM_TOKEN = "8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID = "7013213983"

# Logging
LOG_FILE = "/var/log/propfirmbot-mgmt.log"
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
        logging.StreamHandler(sys.stdout)
    ]
)
log = logging.getLogger("mgmt")

# ─── Helper Functions ────────────────────────────────────────────────────────

def run_cmd(cmd, timeout=30, shell=True):
    """Run a shell command and return (returncode, stdout, stderr)."""
    try:
        result = subprocess.run(
            cmd, shell=shell, capture_output=True, text=True,
            timeout=timeout, env={**os.environ, "DISPLAY": ":99"}
        )
        return result.returncode, result.stdout.strip(), result.stderr.strip()
    except subprocess.TimeoutExpired:
        return -1, "", f"Command timed out after {timeout}s"
    except Exception as e:
        return -1, "", str(e)


def is_process_running(name):
    """Check if a process is running by name."""
    rc, out, _ = run_cmd(f"pgrep -f '{name}'")
    return rc == 0


def get_process_pid(name):
    """Get PID of a process."""
    rc, out, _ = run_cmd(f"pgrep -f '{name}' | head -1")
    return out if rc == 0 else None


def read_json_file(filepath):
    """Read a JSON file, return dict or error dict."""
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {"error": f"File not found: {filepath}"}
    except json.JSONDecodeError as e:
        return {"error": f"Invalid JSON: {e}"}
    except Exception as e:
        return {"error": str(e)}


def tail_file(filepath, lines=50):
    """Read last N lines of a file."""
    try:
        rc, out, _ = run_cmd(f"tail -n {lines} '{filepath}'")
        return out if rc == 0 else f"Error reading {filepath}"
    except Exception as e:
        return str(e)


def send_telegram(message):
    """Send a Telegram message."""
    import urllib.request
    import urllib.parse
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
    data = urllib.parse.urlencode({
        "chat_id": TELEGRAM_CHAT_ID,
        "text": message,
        "parse_mode": "HTML"
    }).encode("utf-8")
    try:
        req = urllib.request.Request(url, data=data)
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode())
    except Exception as e:
        return {"error": str(e)}


# ─── API Action Handlers ────────────────────────────────────────────────────

def handle_status():
    """Full system status overview."""
    mt5_running = is_process_running("terminal64")
    vnc_xvfb = is_process_running("Xvfb")
    vnc_x11vnc = is_process_running("x11vnc")
    watchdog_running = is_process_running("propfirmbot-watchdog") or is_process_running("watchdog")

    # EA status from status.json
    ea_status = read_json_file(os.path.join(CONFIG_DIR, "status.json"))
    ea_active = not ea_status.get("error")

    # Check EA files
    ea_files_exist = os.path.isfile(os.path.join(EA_DIR, "PropFirmBot.ex5"))

    # Check connections
    rc, conns, _ = run_cmd("ss -tn state established | grep -v ':22 \\|:5900 \\|:8888 ' | wc -l")
    active_connections = conns.strip() if rc == 0 else "unknown"

    # Uptime
    rc, uptime, _ = run_cmd("uptime -p")
    uptime_str = uptime if rc == 0 else "unknown"

    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "mt5": {
            "running": mt5_running,
            "pid": get_process_pid("terminal64"),
            "ea_compiled": ea_files_exist,
            "ea_active": ea_active,
            "active_connections": active_connections
        },
        "vnc": {
            "xvfb_running": vnc_xvfb,
            "x11vnc_running": vnc_x11vnc,
            "display": ":99",
            "port": 5900
        },
        "watchdog": {
            "running": watchdog_running
        },
        "vps": {
            "uptime": uptime_str
        },
        "ea_status": ea_status if ea_active else {"status": "not available"}
    }


def handle_health():
    """Quick health check."""
    mt5 = is_process_running("terminal64")
    vnc = is_process_running("Xvfb") and is_process_running("x11vnc")
    return {
        "healthy": mt5 and vnc,
        "mt5_running": mt5,
        "vnc_running": vnc,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }


def handle_positions():
    """Get open positions from status.json."""
    status = read_json_file(os.path.join(CONFIG_DIR, "status.json"))
    if status.get("error"):
        return status
    return {
        "positions": status.get("positions", []),
        "open_count": status.get("open_positions", 0),
        "floating_pnl": status.get("floating_pnl", 0),
        "timestamp": datetime.now(timezone.utc).isoformat()
    }


def handle_account():
    """Get account info from status.json."""
    status = read_json_file(os.path.join(CONFIG_DIR, "status.json"))
    if status.get("error"):
        return status
    return {
        "balance": status.get("balance", 0),
        "equity": status.get("equity", 0),
        "margin": status.get("margin", 0),
        "free_margin": status.get("free_margin", 0),
        "drawdown_pct": status.get("drawdown_pct", 0),
        "equity_high": status.get("equity_high", 0),
        "guardian_state": status.get("guardian_state", "unknown"),
        "open_positions": status.get("open_positions", 0),
        "daily_pnl": status.get("daily_pnl", 0),
        "timestamp": datetime.now(timezone.utc).isoformat()
    }


def handle_logs(params):
    """Get recent logs."""
    source = params.get("source", ["ea"])[0]
    lines = min(int(params.get("lines", ["50"])[0]), 500)

    if source == "terminal":
        # Find most recent terminal log
        log_dir = TERMINAL_LOGS_DIR
        rc, latest, _ = run_cmd(f"ls -t '{log_dir}'/*.log 2>/dev/null | head -1")
        if rc != 0 or not latest:
            return {"error": "No terminal logs found", "log_dir": log_dir}
        content = tail_file(latest, lines)
        return {"source": "terminal", "file": latest, "lines": lines, "content": content}

    elif source == "ea":
        # Find most recent EA log
        log_dir = EA_LOGS_DIR
        rc, latest, _ = run_cmd(f"ls -t '{log_dir}'/*.log 2>/dev/null | head -1")
        if rc != 0 or not latest:
            return {"error": "No EA logs found", "log_dir": log_dir}
        content = tail_file(latest, lines)
        return {"source": "ea", "file": latest, "lines": lines, "content": content}

    elif source == "mgmt":
        content = tail_file(LOG_FILE, lines)
        return {"source": "management", "file": LOG_FILE, "lines": lines, "content": content}

    else:
        return {"error": f"Unknown log source: {source}. Use: ea, terminal, mgmt"}


def handle_system():
    """VPS system information."""
    rc_cpu, cpu, _ = run_cmd("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1")
    rc_mem, mem, _ = run_cmd("free -m | awk '/Mem:/ {printf \"%.1f%% (%dMB / %dMB)\", $3/$2*100, $3, $2}'")
    rc_disk, disk, _ = run_cmd("df -h / | awk 'NR==2 {printf \"%s used of %s (%s)\", $3, $2, $5}'")
    rc_up, uptime, _ = run_cmd("uptime -p")
    rc_load, load, _ = run_cmd("cat /proc/loadavg | awk '{print $1, $2, $3}'")

    return {
        "cpu_usage": f"{cpu}%" if rc_cpu == 0 else "unknown",
        "memory": mem if rc_mem == 0 else "unknown",
        "disk": disk if rc_disk == 0 else "unknown",
        "uptime": uptime if rc_up == 0 else "unknown",
        "load_average": load if rc_load == 0 else "unknown",
        "timestamp": datetime.now(timezone.utc).isoformat()
    }


def handle_ea_status():
    """Detailed EA status from status.json."""
    status = read_json_file(os.path.join(CONFIG_DIR, "status.json"))
    if status.get("error"):
        # Try to check if EA files exist at least
        ea_exists = os.path.isfile(os.path.join(EA_DIR, "PropFirmBot.ex5"))
        return {
            "ea_compiled": ea_exists,
            "status_json": status,
            "note": "status.json not available - EA may not be writing it"
        }
    return status


def handle_config():
    """Current configuration files."""
    configs = {}
    for fname in ["risk_params.json", "funded_rules.json", "symbols.json",
                   "notifications.json", "account_state.json", "challenge_rules.json"]:
        filepath = os.path.join(CONFIG_DIR, fname)
        if os.path.exists(filepath):
            configs[fname] = read_json_file(filepath)
        else:
            # Try repo configs
            repo_path = os.path.join(REPO_DIR, "configs", fname)
            if os.path.exists(repo_path):
                configs[fname] = read_json_file(repo_path)
                configs[fname]["_source"] = "repo (not deployed)"
    return configs


def handle_journal(params):
    """Recent trade journal entries."""
    lines = min(int(params.get("lines", ["20"])[0]), 200)
    # Look for journal CSV files
    rc, files, _ = run_cmd(f"ls -t '{CONFIG_DIR}'/journal*.csv '{CONFIG_DIR}'/trade*.csv 2>/dev/null | head -1")
    if rc != 0 or not files:
        return {"error": "No trade journal files found", "search_dir": CONFIG_DIR}
    content = tail_file(files.strip(), lines)
    return {"file": files.strip(), "lines": lines, "content": content}


def handle_processes():
    """List relevant running processes."""
    rc, out, _ = run_cmd("ps aux | grep -E '(terminal64|Xvfb|x11vnc|wineserver|python3.*server|watchdog)' | grep -v grep")
    processes = []
    if rc == 0 and out:
        for line in out.split("\n"):
            parts = line.split(None, 10)
            if len(parts) >= 11:
                processes.append({
                    "user": parts[0],
                    "pid": parts[1],
                    "cpu": parts[2],
                    "mem": parts[3],
                    "command": parts[10][:100]
                })
    return {"processes": processes, "count": len(processes)}


# ─── POST Action Handlers ───────────────────────────────────────────────────

def handle_restart_mt5():
    """Restart MetaTrader 5."""
    log.info("Restarting MT5...")
    send_telegram("🔄 <b>MT5 Restart</b>\nRestarting MT5 via management API...")

    # Kill MT5
    run_cmd("pkill -f terminal64", timeout=10)
    time.sleep(3)

    # Make sure wineserver is clean
    run_cmd("wineserver -k", timeout=10)
    time.sleep(2)

    # Start MT5
    rc, out, err = run_cmd(
        'DISPLAY=:99 wine "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" &',
        timeout=10
    )
    time.sleep(5)

    mt5_running = is_process_running("terminal64")
    status = "success" if mt5_running else "failed"

    msg = f"{'✅' if mt5_running else '❌'} MT5 restart: {status}"
    send_telegram(msg)
    log.info(f"MT5 restart: {status}")

    return {
        "action": "restart_mt5",
        "status": status,
        "mt5_running": mt5_running,
        "pid": get_process_pid("terminal64"),
        "timestamp": datetime.now(timezone.utc).isoformat()
    }


def handle_start_mt5():
    """Start MT5 if not running."""
    if is_process_running("terminal64"):
        return {"action": "start_mt5", "status": "already_running",
                "pid": get_process_pid("terminal64")}

    log.info("Starting MT5...")
    run_cmd(
        'DISPLAY=:99 wine "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" &',
        timeout=10
    )
    time.sleep(5)

    mt5_running = is_process_running("terminal64")
    status = "started" if mt5_running else "failed"
    send_telegram(f"{'✅' if mt5_running else '❌'} MT5 start: {status}")

    return {
        "action": "start_mt5",
        "status": status,
        "mt5_running": mt5_running,
        "pid": get_process_pid("terminal64")
    }


def handle_stop_mt5():
    """Stop MT5."""
    log.info("Stopping MT5...")
    run_cmd("pkill -f terminal64", timeout=10)
    time.sleep(3)
    mt5_running = is_process_running("terminal64")
    return {
        "action": "stop_mt5",
        "status": "stopped" if not mt5_running else "still_running",
        "mt5_running": mt5_running
    }


def handle_restart_vnc():
    """Restart VNC server."""
    log.info("Restarting VNC...")

    # Kill existing
    run_cmd("pkill x11vnc", timeout=5)
    run_cmd("pkill Xvfb", timeout=5)
    time.sleep(2)

    # Start Xvfb
    run_cmd("Xvfb :99 -screen 0 1280x1024x24 &", timeout=5)
    time.sleep(2)

    # Start x11vnc
    run_cmd("x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw", timeout=5)
    time.sleep(2)

    xvfb = is_process_running("Xvfb")
    x11vnc = is_process_running("x11vnc")

    return {
        "action": "restart_vnc",
        "status": "success" if (xvfb and x11vnc) else "partial",
        "xvfb_running": xvfb,
        "x11vnc_running": x11vnc,
        "port": 5900
    }


def handle_deploy():
    """Git pull + deploy EA and config files to MT5."""
    log.info("Starting deployment...")
    send_telegram("📦 <b>Deployment Started</b>\nPulling latest code and deploying...")

    results = {}

    # Git pull
    rc, out, err = run_cmd(f"cd {REPO_DIR} && git pull origin claude/build-cfd-trading-bot-fl0ld", timeout=60)
    results["git_pull"] = {
        "status": "success" if rc == 0 else "failed",
        "output": out[:500],
        "error": err[:200] if err else None
    }

    if rc != 0:
        send_telegram(f"❌ Git pull failed: {err[:200]}")
        results["status"] = "failed_at_git_pull"
        return results

    # Deploy EA files
    rc, out, err = run_cmd(f'cp -v {REPO_DIR}/EA/* "{EA_DIR}/"', timeout=30)
    results["ea_deploy"] = {
        "status": "success" if rc == 0 else "failed",
        "output": out[:500]
    }

    # Deploy config files
    rc, out, err = run_cmd(f'cp -v {REPO_DIR}/configs/* "{CONFIG_DIR}/"', timeout=30)
    results["config_deploy"] = {
        "status": "success" if rc == 0 else "failed",
        "output": out[:500]
    }

    all_ok = (results["ea_deploy"]["status"] == "success" and
              results["config_deploy"]["status"] == "success")
    results["status"] = "success" if all_ok else "partial"
    results["note"] = "Files deployed. Restart MT5 to load new EA code."
    results["timestamp"] = datetime.now(timezone.utc).isoformat()

    emoji = "✅" if all_ok else "⚠️"
    send_telegram(f"{emoji} <b>Deployment Complete</b>\nEA: {results['ea_deploy']['status']}, Config: {results['config_deploy']['status']}")
    log.info(f"Deployment: {results['status']}")

    return results


def handle_telegram_test():
    """Send a test Telegram message."""
    result = send_telegram(
        "🧪 <b>Test Message</b>\n"
        f"Management API is working!\n"
        f"Time: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}"
    )
    return {
        "action": "telegram_test",
        "status": "sent" if not result.get("error") else "failed",
        "result": result
    }


def handle_exec(params):
    """Execute a whitelisted command."""
    cmd = params.get("cmd", [""])[0]
    if not cmd:
        return {"error": "No command provided. Use ?cmd=COMMAND"}

    # Whitelist of allowed command prefixes
    ALLOWED_PREFIXES = [
        "ls ", "cat ", "head ", "tail ", "grep ", "wc ",
        "df ", "free ", "uptime", "top -bn1", "ps ",
        "pgrep ", "ss ", "netstat ",
        "wine --version", "uname ",
        "systemctl status", "systemctl is-active",
        "du -sh", "date", "whoami", "hostname",
        "cat /proc/loadavg", "cat /proc/meminfo",
        "journalctl --no-pager -n",
    ]

    allowed = any(cmd.startswith(prefix) for prefix in ALLOWED_PREFIXES)
    if not allowed:
        return {
            "error": "Command not in whitelist",
            "command": cmd,
            "allowed_prefixes": ALLOWED_PREFIXES
        }

    log.info(f"Executing whitelisted command: {cmd}")
    rc, out, err = run_cmd(cmd, timeout=30)
    return {
        "command": cmd,
        "returncode": rc,
        "stdout": out[:5000],
        "stderr": err[:1000] if err else None
    }


# ─── HTTP Request Handler ───────────────────────────────────────────────────

# Route table
GET_ROUTES = {
    "/api/status": handle_status,
    "/api/health": handle_health,
    "/api/positions": handle_positions,
    "/api/account": handle_account,
    "/api/ea-status": handle_ea_status,
    "/api/config": handle_config,
    "/api/processes": handle_processes,
    "/api/system": handle_system,
}

GET_ROUTES_WITH_PARAMS = {
    "/api/logs": handle_logs,
    "/api/journal": handle_journal,
    "/api/exec": handle_exec,
}

POST_ROUTES = {
    "/api/restart-mt5": handle_restart_mt5,
    "/api/restart-vnc": handle_restart_vnc,
    "/api/deploy": handle_deploy,
    "/api/start-mt5": handle_start_mt5,
    "/api/stop-mt5": handle_stop_mt5,
    "/api/telegram-test": handle_telegram_test,
}


class ManagementHandler(BaseHTTPRequestHandler):
    """HTTP request handler for the management API."""

    def log_message(self, format, *args):
        """Override to use our logger."""
        log.info(f"{self.client_address[0]} - {format % args}")

    def send_json(self, data, status=200):
        """Send JSON response."""
        body = json.dumps(data, indent=2, ensure_ascii=False, default=str).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def check_auth(self, params):
        """Check authentication token."""
        token = params.get("token", [None])[0]
        if not token:
            # Also check header
            token = self.headers.get("X-Auth-Token")
        if token != AUTH_TOKEN:
            return False
        return True

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        params = parse_qs(parsed.query)

        # Health check doesn't need auth (for monitoring tools)
        if path == "/api/ping":
            self.send_json({"pong": True, "time": datetime.now(timezone.utc).isoformat()})
            return

        # Auth check
        if not self.check_auth(params):
            self.send_json({"error": "Unauthorized. Provide ?token=AUTH_TOKEN"}, 401)
            return

        # Route: simple GET
        if path in GET_ROUTES:
            try:
                result = GET_ROUTES[path]()
                self.send_json(result)
            except Exception as e:
                log.error(f"Error in {path}: {e}")
                self.send_json({"error": str(e)}, 500)
            return

        # Route: GET with params
        if path in GET_ROUTES_WITH_PARAMS:
            try:
                result = GET_ROUTES_WITH_PARAMS[path](params)
                self.send_json(result)
            except Exception as e:
                log.error(f"Error in {path}: {e}")
                self.send_json({"error": str(e)}, 500)
            return

        # POST routes also accept GET (for WebFetch compatibility)
        if path in POST_ROUTES:
            confirm = params.get("confirm", [""])[0]
            if confirm != "yes":
                self.send_json({
                    "error": "Action requires confirmation",
                    "action": path,
                    "hint": f"Add &confirm=yes to execute: {path}?token=...&confirm=yes"
                }, 400)
                return
            try:
                result = POST_ROUTES[path]()
                self.send_json(result)
            except Exception as e:
                log.error(f"Error in {path}: {e}")
                self.send_json({"error": str(e)}, 500)
            return

        # API index
        if path in ("/api", "/api/"):
            self.send_json({
                "name": "PropFirmBot Management API",
                "version": "1.0",
                "endpoints": {
                    "GET": list(GET_ROUTES.keys()) + list(GET_ROUTES_WITH_PARAMS.keys()),
                    "POST (use &confirm=yes)": list(POST_ROUTES.keys()),
                    "no-auth": ["/api/ping"]
                }
            })
            return

        self.send_json({"error": "Not found", "path": path}, 404)

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        params = parse_qs(parsed.query)

        # Read POST body for params
        content_length = int(self.headers.get("Content-Length", 0))
        if content_length > 0:
            body = self.rfile.read(content_length).decode("utf-8")
            try:
                body_params = json.loads(body)
                for k, v in body_params.items():
                    params[k] = [v] if not isinstance(v, list) else v
            except json.JSONDecodeError:
                pass

        if not self.check_auth(params):
            self.send_json({"error": "Unauthorized"}, 401)
            return

        if path in POST_ROUTES:
            try:
                result = POST_ROUTES[path]()
                self.send_json(result)
            except Exception as e:
                log.error(f"Error in {path}: {e}")
                self.send_json({"error": str(e)}, 500)
            return

        # exec needs params
        if path == "/api/exec":
            try:
                result = handle_exec(params)
                self.send_json(result)
            except Exception as e:
                self.send_json({"error": str(e)}, 500)
            return

        self.send_json({"error": "Not found"}, 404)

    def do_OPTIONS(self):
        """Handle CORS preflight."""
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "X-Auth-Token, Content-Type")
        self.end_headers()


# ─── Server Startup ──────────────────────────────────────────────────────────

def main():
    # Ensure log directory exists
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)

    server = HTTPServer((BIND_ADDRESS, PORT), ManagementHandler)
    log.info(f"PropFirmBot Management API starting on {BIND_ADDRESS}:{PORT}")
    log.info(f"MT5 dir: {MT5_DIR}")
    log.info(f"Repo dir: {REPO_DIR}")

    # Graceful shutdown
    def shutdown(signum, frame):
        log.info("Shutting down management API...")
        server.shutdown()
        sys.exit(0)

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    try:
        send_telegram(
            "🟢 <b>Management API Started</b>\n"
            f"Port: {PORT}\n"
            f"Time: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}"
        )
    except Exception:
        pass

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log.info("Interrupted, shutting down...")
        server.shutdown()


if __name__ == "__main__":
    main()
