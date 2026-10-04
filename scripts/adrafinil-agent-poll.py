#!/usr/bin/env python3
"""Reconcile activity-only Adrafinil holds from a macOS LaunchAgent every minute."""

import argparse
import json
import math
import os
import plistlib
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

# Section: Poll timing and recognized identities
LABEL = "com.dboyza.adrafinil-agent-poll"
POLL_INTERVAL_SECONDS = 60
FALLBACK_TTL_SECONDS = 180
APPLE_EPOCH_SECONDS = 978307200
SESSION_KEY = re.compile(r"^codex:([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})$")
KEY_PATTERN = re.compile(r"^(codex|claude-code):dotfiles-poll:[1-9][0-9]*$")
CODEX_ASSERTION = re.compile(
    r'^\s*pid (\d+)\(codex\):.*\bPreventUserIdleSystemSleep\b'
    r'.*named: "Codex is running an active turn"\s*$', re.MULTILINE
)


# Section: External observations and validation
def run(args):
    result = subprocess.run(
        [str(arg) for arg in args], input="", text=True, capture_output=True,
        timeout=10, check=True, env={**os.environ, "LC_ALL": "C"},
    )
    # Adrafinil deliberately exits zero for failed hooks; stderr is significant.
    if result.stderr.strip():
        raise RuntimeError(result.stderr.strip())
    return result.stdout


def number(value):
    return type(value) in (int, float) and math.isfinite(value)


def validate_status(status):
    if isinstance(status, dict) and status.get("daemonRunning") is False:
        raise RuntimeError("Adrafinil is not running; open the Adrafinil app.")
    if not isinstance(status, dict) or type(status.get("paused")) is not bool or not isinstance(status.get("assertions"), list):
        raise RuntimeError("Unrecognized Adrafinil status; no holds changed.")
    keys = []
    for entry in status["assertions"]:
        if not isinstance(entry, dict) or not isinstance(entry.get("key"), str) or not entry["key"]:
            raise RuntimeError("Unrecognized Adrafinil assertion; no holds changed.")
        if "pid" in entry and type(entry["pid"]) is not int:
            raise RuntimeError("Invalid PID in Adrafinil status; no holds changed.")
        if any(name in entry and not isinstance(entry[name], str) for name in ("tool", "origin")):
            raise RuntimeError("Invalid tool or origin in Adrafinil status; no holds changed.")
        if any(entry.get(name) is not None and not number(entry[name]) for name in ("acquiredAt", "lastActivityAt", "expiresAt")):
            raise RuntimeError("Invalid timestamp in Adrafinil status; no holds changed.")
        keys.append(entry["key"])
    if len(set(keys)) != len(keys):
        raise RuntimeError("Duplicate keys in Adrafinil status; no holds changed.")
    return status


# Section: Process identity and socket ownership
def process_snapshot(text):
    """Validate a complete ps read and retain birth times to detect reused PIDs."""
    rows, starts = [], {}
    for line in text.splitlines():
        match = re.fullmatch(r"\s*(\d+)\s+(\d+)\s+(\w{3} \w{3}\s+\d+ \d{2}:\d{2}:\d{2} \d{4})\s+(.+)", line)
        if not match:
            raise RuntimeError("Unrecognized process snapshot; no holds changed.")
        pid, uid, born, executable = match.groups()
        if int(pid) in starts:
            raise RuntimeError("Duplicate PID in process snapshot; no holds changed.")
        # ps emits local wall time; astimezone applies the local zone at birth.
        starts[int(pid)] = datetime.strptime(born, "%a %b %d %H:%M:%S %Y").astimezone().timestamp()
        rows.append(f"{pid} {uid} {executable}")
    if os.getpid() not in starts:
        raise RuntimeError("Incomplete process snapshot; no holds changed.")
    return "\n".join(rows), starts


def codex_socket_peers(text, candidates):
    """Match client socket peers to Codex daemon endpoints, without reading traffic."""
    records, record, pid = [], {}, None
    for line in text.splitlines() + ["f"]:
        field, value = line[:1], line[1:]
        if field in ("p", "f"):
            if record:
                records.append(record)
            if field == "p":
                pid = int(value) if value.isdigit() else None
            record = {"pid": pid}
        elif field in ("d", "n"):
            record[field] = value
    servers = {}
    for record in records:
        name, device = record.get("n", ""), record.get("d", "")
        if record.get("pid") in candidates and re.fullmatch(r"0x[0-9a-f]+", device) and re.fullmatch(r"/(?:private/)?tmp/codex-daemon-\d+/[0-9a-f]+", name):
            servers.setdefault(device, set()).add(record["pid"])
    peers = {}
    for record in records:
        target = record.get("n", "").removeprefix("->")
        if record.get("pid") in candidates and record.get("n", "").startswith("->"):
            for server in servers.get(target, ()):
                if server != record["pid"]:
                    peers.setdefault(record["pid"], set()).add(server)
    return peers


def read_codex_peers(process_map, status, active):
    candidates = {pid for pid, tool in process_map.items() if tool == "codex"}
    owners = {a.get("pid") for a in status["assertions"] if a.get("tool") == "codex" and a.get("origin") in ("hook", "sniffed") and not KEY_PATTERN.fullmatch(a["key"])}
    if not owners & candidates or not any(tool == "codex" and pid not in owners for pid, tool in active.items()):
        return {}, []
    try:
        text = run(["/usr/sbin/lsof", "-nP", "-a", "-p", ",".join(map(str, sorted(candidates))), "-U", "-F", "pfdn"])
        return codex_socket_peers(text, candidates), []
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        # Lack of socket visibility must not suppress a needed fallback hold.
        return {}, [f"Codex socket coverage unavailable: {error}"]


def processes(text, uid):
    """Use executable names, never substring matches against prompts/arguments."""
    found = {}
    for line in text.splitlines():
        fields = line.split(None, 2)
        if len(fields) != 3 or not fields[0].isdigit() or fields[1] != str(uid):
            continue
        pid, executable = int(fields[0]), Path(fields[2])
        if executable.name == "codex":
            found[pid] = "codex"
        elif executable.name == "claude" or (
            executable.parent.name == "versions"
            and executable.parent.parent.name == "claude"
            and re.fullmatch(r"\d+\.\d+\.\d+", executable.name)
        ):
            found[pid] = "claude-code"
    return found


# Section: Active-turn and session evidence
def active_agents(process_map, assertions, sessions, starts=None):
    active = {
        int(pid): "codex" for pid in CODEX_ASSERTION.findall(assertions)
        if process_map.get(int(pid)) == "codex"
    }
    uncertain = {pid for pid, tool in process_map.items() if tool == "claude-code"}
    for path in sessions.glob("*.json"):
        if not re.fullmatch(r"[1-9][0-9]*\.json", path.name):
            continue
        try:
            status = json.loads(path.read_text())
        except (OSError, ValueError):
            continue  # Claude rewrites in place, so a partial read is possible.
        if not isinstance(status, dict):
            continue
        pid = status.get("pid")
        if starts and type(pid) is int:
            born, started = starts.get(pid), status.get("startedAt")
            if born is None or not number(started) or started / 1000 < born - 1:
                continue  # Stale status from a previous process with this PID.
        if (
            type(pid) is int and str(pid) == path.stem
            and process_map.get(pid) == "claude-code"
            and status.get("status") in ("busy", "idle", "waiting")
            and isinstance(status.get("sessionId"), str) and status["sessionId"]
        ):
            uncertain.discard(pid)
            if status["status"] == "busy":
                active[pid] = "claude-code"
    return active, uncertain


def codex_session_state(home, session_id):
    """Read lifecycle metadata only; an unavailable index is not a dead session."""
    databases = sorted(
        (p for p in home.glob("state_*.sqlite") if p.stem[6:].isdigit()),
        key=lambda p: int(p.stem[6:]), reverse=True,
    )
    if not databases:
        return None
    try:
        connection = sqlite3.connect(databases[0].as_uri() + "?mode=ro", uri=True, timeout=1)
        try:
            row = connection.execute("SELECT rollout_path FROM threads WHERE id = ?", (session_id,)).fetchone()
        finally:
            connection.close()
        if row is None:
            # A migrated or archived session can have a rollout but no index row.
            paths = list(home.glob(f"sessions/*/*/*/*-{session_id}.jsonl"))
            paths += list(home.glob(f"archived_sessions/*-{session_id}.jsonl"))
            if not paths:
                return None  # Ephemeral/custom-home sessions may not be indexed here.
            path = max(paths, key=lambda p: p.stat().st_mtime)
        else:
            path = Path(row[0])
        # Bound reads of large transcripts. No recent lifecycle marker means unknown.
        with path.open("rb") as stream:
            size = stream.seek(0, os.SEEK_END)
            start = max(0, size - 1024 * 1024)
            stream.seek(start)
            if start:
                stream.readline()
            tail = stream.read()
        if not tail.endswith(b"\n"):
            return None  # The writer has not finished its current record.
        for line in reversed(tail.splitlines()):
            record = json.loads(line)
            if not isinstance(record, dict) or record.get("type") != "event_msg":
                continue
            event = record.get("payload")
            if not isinstance(event, dict):
                continue
            kind = event.get("type")
            if kind not in ("task_started", "task_complete", "turn_aborted"):
                continue
            stamp = record.get("timestamp")
            if not isinstance(stamp, str):
                return None
            parsed = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
            if parsed.tzinfo is None:
                return None
            timestamp = parsed.timestamp()
            return ("active" if kind == "task_started" else "idle", timestamp)
    except (OSError, ValueError, TypeError, KeyError, sqlite3.Error):
        pass
    return None


# Section: Native hold lifecycle decisions
def stale_agent_holds(status, process_text, sessions, codex_home, starts=None):
    """Identify abandoned native holds without treating a shared server as work."""
    if not isinstance(status, dict) or not isinstance(status.get("assertions"), list):
        return {}
    live_pids = {
        int(fields[0]) for line in process_text.splitlines()
        if len(fields := line.split(None, 2)) == 3 and fields[0].isdigit()
    }
    stale = {}
    for entry in status.get("assertions", []):
        if not isinstance(entry, dict):
            continue
        key, tool, pid = entry.get("key"), entry.get("tool"), entry.get("pid")
        if (
            tool not in ("codex", "claude-code")
            or entry.get("origin") not in ("hook", "sniffed")
            or not isinstance(key, str) or KEY_PATTERN.fullmatch(key)
            or key.startswith("hold:")
        ):
            continue
        if type(pid) is int and pid > 0 and pid not in live_pids:
            stale[key] = "owning process exited"
            continue
        touched = entry.get("lastActivityAt", entry.get("acquiredAt"))
        if starts and pid in starts and number(touched) and touched + APPLE_EPOCH_SECONDS < starts[pid] - 1:
            stale[key] = "owning PID was reused by a newer process"
            continue
        if tool == "codex" and (match := SESSION_KEY.fullmatch(key)):
            activity = codex_session_state(codex_home, match[1])
            touched = entry.get("lastActivityAt", entry.get("acquiredAt"))
            if activity is None or not number(touched):
                continue
            touched += APPLE_EPOCH_SECONDS
            state, timestamp = activity
            if state == "idle" and timestamp >= touched:
                stale[key] = "Codex turn completed or was interrupted"
        elif tool == "claude-code" and type(pid) is int and pid > 0:
            try:
                session = json.loads((sessions / f"{pid}.json").read_text())
            except (OSError, ValueError):
                continue
            if (
                isinstance(session, dict) and session.get("pid") == pid
                and isinstance(session.get("sessionId"), str)
                and key == f"claude-code:{session['sessionId']}"
                and session.get("status") == "idle"
            ):
                # A start hook can precede Claude's busy-status write.
                updated = session.get("statusUpdatedAt")
                touched = entry.get("lastActivityAt", entry.get("acquiredAt"))
                if number(updated) and number(touched) and updated / 1000 >= touched + APPLE_EPOCH_SECONDS:
                    stale[key] = "Claude session is idle"
    return stale


# Section: Release race checks and native coverage
def hold_identity(entry):
    return tuple(entry.get(field) for field in ("tool", "pid", "origin", "acquiredAt", "lastActivityAt", "expiresAt"))


def release_hold(cli, key):
    try:
        run([cli, "release", key])
    except RuntimeError:
        # Stop hooks and the daemon's exit watcher may win the release race.
        latest = validate_status(json.loads(run([cli, "status", "--json"])))
        if not any(entry["key"] == key for entry in latest["assertions"]):
            return
        raise


def native_coverage(status, stale, peers=None):
    """A valid native hold already protects this tool and process."""
    covered = set()
    now = datetime.now(timezone.utc).timestamp() - APPLE_EPOCH_SECONDS
    for entry in status["assertions"]:
        if not isinstance(entry, dict):
            continue
        key, pid, tool = entry.get("key"), entry.get("pid"), entry.get("tool")
        if (
            not isinstance(key, str) or KEY_PATTERN.fullmatch(key) or key in stale
            or key.startswith("hold:") or entry.get("origin") not in ("hook", "sniffed")
            or type(pid) is not int or pid <= 0 or tool not in ("codex", "claude-code")
        ):
            continue
        expires = entry.get("expiresAt")
        # A nearly expired hold cannot cover active work until our next tick.
        if expires is not None and (not number(expires) or expires <= now + POLL_INTERVAL_SECONDS):
            continue
        covered.add((tool, pid))
    servers = {pid for tool, pid in covered if tool == "codex"}
    covered.update(("codex", pid) for pid, owners in (peers or {}).items() if servers & owners)
    return covered


# Section: Pure fallback planning
def plan_fallback_holds(active, status, uncertain, stale, peers):
    """Decide fallback changes from observations; unknown activity stays protected."""
    covered = native_coverage(status, stale, peers)
    owned = {
        entry["key"] for entry in status["assertions"]
        if isinstance(entry, dict) and isinstance(entry.get("key"), str)
        and KEY_PATTERN.fullmatch(entry["key"])
    }
    desired = {
        f"{tool}:dotfiles-poll:{pid}": (pid, tool)
        for pid, tool in active.items() if (tool, pid) not in covered
    }
    # Unknown activity keeps its existing lease without renewing it.
    removable = {
        key for key in owned - desired.keys()
        if int(key.rsplit(":", 1)[1]) not in uncertain
    }
    return covered, desired, removable


# Section: Apply acquisitions before guarded releases
def reconcile(cli, active, status, dry_run=False, uncertain=(), stale=None, peers=None):
    validate_status(status)
    if status["paused"]:
        return {"paused": True, "active": active, "acquired": [], "released": []}
    stale = dict(stale or {})
    covered, desired, removable = plan_fallback_holds(active, status, uncertain, stale, peers)
    errors, acquired, paused = [], [], False

    def acquire(key, pid, tool):
        try:
            if not dry_run:
                run([cli, "acquire", key, "--tool", tool, "--pid", pid,
                     "--ttl", FALLBACK_TTL_SECONDS, "--reason", "Active work detected by the one-minute check"])
            acquired.append(key)
        except (OSError, RuntimeError, subprocess.SubprocessError) as error:
            errors.append(f"{key}: {error}")
            # The CLI can warn that --pid died yet acquire under an ancestor PID.
            # Remove that unintended fallback instead of treating exit 0 as success.
            try:
                latest = validate_status(json.loads(run([cli, "status", "--json"])))
                wrong = next((a for a in latest["assertions"] if a["key"] == key and a.get("pid") != pid), None)
                if wrong:
                    release_hold(cli, key)
            except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as followup:
                errors.append(f"{key}: acquire verification failed: {followup}")

    # Acquire first so a handoff between agents never briefly drops our last hold.
    for key, (pid, tool) in sorted(desired.items()):
        acquire(key, pid, tool)
    # Do not remove native protection if obtaining its replacement just failed.
    pending = sorted(removable | (stale.keys() if not errors else set()))
    released = []
    before = {entry["key"]: entry for entry in status["assertions"]}
    for key in pending:
        try:
            if not dry_run:
                if key in stale:
                    if errors:
                        continue
                    # Recheck each hold immediately before releasing it, not once
                    # for the whole batch: another turn can start between keys.
                    latest = validate_status(json.loads(run([cli, "status", "--json"])))
                    after = {entry["key"]: entry for entry in latest["assertions"]}
                    if latest["paused"]:
                        paused = True
                        break
                    daemon_changed = latest.get("daemonBootID") != status.get("daemonBootID")
                    hold_missing = key not in before or key not in after
                    if daemon_changed or hold_missing:
                        continue
                    hold_changed = hold_identity(before[key]) != hold_identity(after[key])
                    if hold_changed:
                        continue
                else:
                    pid = int(key.rsplit(":", 1)[1])
                    tool = key.split(":", 1)[0]
                    if active.get(pid) == tool and (tool, pid) in covered:
                        # Check at the actual handoff, after any other CLI calls.
                        latest = validate_status(json.loads(run([cli, "status", "--json"])))
                        if latest["paused"]:
                            paused = True
                            break
                        if (tool, pid) not in native_coverage(latest, stale, peers):
                            covered.discard((tool, pid))
                            acquire(key, pid, tool)
                            continue
                release_hold(cli, key)
            released.append(key)
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
            errors.append(f"{key}: {error}")
    return {
        "paused": paused, "active": active, "acquired": acquired, "released": released,
        "staleReasons": {key: stale[key] for key in released if key in stale}, "errors": errors,
        "coveredByNative": {pid: tool for pid, tool in active.items() if (tool, pid) in covered},
    }


# Section: CLI discovery and LaunchAgent installation
def cli_path():
    candidates = [Path.home() / ".local/bin/adrafinil"]
    if shutil.which("adrafinil"):
        candidates.append(Path(shutil.which("adrafinil")))
    candidates += [
        Path("/Applications/Adrafinil.app/Contents/Helpers/adrafinil"),
        Path.home() / "Applications/Adrafinil.app/Contents/Helpers/adrafinil",
    ]
    for candidate in candidates:
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return candidate.absolute()
    raise RuntimeError("Install and set up Adrafinil before installing its activity poller.")


def atomic_write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(content)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def launch_agent(home, python, script, cli):
    return {
        "Label": LABEL,
        "ProgramArguments": [str(python), "-B", str(script), "--cli", str(cli)],
        "RunAtLoad": True,
        "StartInterval": POLL_INTERVAL_SECONDS,
        "ProcessType": "Background",
        "EnvironmentVariables": {"HOME": str(home), **{
            name: str(Path(os.environ[name]).expanduser().absolute())
            for name in ("CODEX_HOME", "CLAUDE_CONFIG_DIR") if os.environ.get(name)
        }},
        "StandardErrorPath": str(home / ".local/state/dotfiles/adrafinil-poll/error.log"),
    }


def install(cli):
    home = Path.home()
    state = home / ".local/state/dotfiles/adrafinil-poll"
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    plist = home / "Library/LaunchAgents" / f"{LABEL}.plist"
    # Keep Homebrew's stable symlink, not its replaceable Cellar-version path.
    python = next(
        (str(path) for path in [Path("/opt/homebrew/bin/python3"), Path("/usr/local/bin/python3")]
         if path.is_file() and os.access(path, os.X_OK)),
        shutil.which("python3") or sys.executable,
    )
    definition = launch_agent(home, python, Path(__file__).resolve(), cli)
    old_data = plist.read_bytes() if plist.exists() else None
    if old_data is not None:
        previous = plistlib.loads(old_data)
        if not isinstance(previous, dict) or previous.get("Label") != LABEL:
            raise RuntimeError(f"Refusing to replace unrelated LaunchAgent: {plist}")
    domain = f"gui/{os.getuid()}"
    loaded = subprocess.run(
        ["/bin/launchctl", "print", f"{domain}/{LABEL}"], capture_output=True,
        timeout=10, check=False,
    ).returncode == 0
    if loaded and old_data is None:
        raise RuntimeError("The poller is loaded without a saved LaunchAgent; refusing an unrecoverable replacement.")
    if loaded:
        run(["/bin/launchctl", "bootout", f"{domain}/{LABEL}"])
    try:
        atomic_write(plist, plistlib.dumps(definition))
        run(["/bin/launchctl", "bootstrap", domain, plist])
    except (OSError, RuntimeError, subprocess.SubprocessError):
        if old_data is None:
            plist.unlink(missing_ok=True)
        else:
            atomic_write(plist, old_data)
            if loaded:
                run(["/bin/launchctl", "bootstrap", domain, plist])
        raise
    print(f"Installed {plist}; checks every {POLL_INTERVAL_SECONDS} seconds while the Mac is awake.")


# Section: Serialized polling and CLI entry point
@contextmanager
def poll_lock(path):
    import fcntl

    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with path.open("a") as stream:
        try:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            yield False
            return
        try:
            yield True
        finally:
            fcntl.flock(stream, fcntl.LOCK_UN)


def poll_once(cli, dry_run):
    # Observe and validate first. Failed observations must never release protection.
    status = validate_status(json.loads(run([cli, "status", "--json"])))
    if status["paused"]:
        return {"paused": True, "active": {}, "acquired": [], "released": []}
    process_text, starts = process_snapshot(run(["/bin/ps", "-axo", "pid=,uid=,lstart=,comm="]))
    snapshot = processes(process_text, os.getuid())
    power = run(["/usr/bin/pmset", "-g", "assertions"])
    has_header = "Assertion status system-wide:" in power
    has_process_section = any(marker in power for marker in ("Listed by owning process:", "No assertions."))
    if not has_header or not has_process_section:
        raise RuntimeError("Unrecognized power assertion snapshot; no holds changed.")
    sessions = Path(os.environ.get("CLAUDE_CONFIG_DIR", str(Path.home() / ".claude"))).expanduser().absolute() / "sessions"
    codex_home = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))).expanduser().absolute()
    active, uncertain = active_agents(snapshot, power, sessions, starts)
    stale = stale_agent_holds(status, process_text, sessions, codex_home, starts)
    peers, warnings = read_codex_peers(snapshot, status, active)
    result = reconcile(cli, active, status, dry_run, uncertain, stale, peers)
    result["uncertainPids"] = sorted(uncertain)
    result["warnings"] = warnings
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--install", action="store_true", help="Install and load the per-user LaunchAgent")
    mode.add_argument("--dry-run", action="store_true", help="Show detected activity and planned holds without changes")
    parser.add_argument("--cli", type=Path, help="Path to the Adrafinil CLI")
    args = parser.parse_args()
    if sys.platform != "darwin":
        print("Adrafinil activity polling is macOS-only; nothing changed.")
        return 0
    try:
        cli = args.cli or cli_path()
        if args.install:
            install(cli)
            return 0
        state = Path.home() / ".local/state/dotfiles/adrafinil-poll"
        if args.dry_run:
            result = poll_once(cli, True)
        else:
            with poll_lock(state / "poll.lock") as locked:
                if not locked:
                    return 0
                result = poll_once(cli, False)
                result["checkedAt"] = datetime.now(timezone.utc).isoformat()
                atomic_write(state / "status.json", json.dumps(result, indent=2).encode())
        result["checkedAt"] = datetime.now(timezone.utc).isoformat()
        if args.dry_run:
            print(json.dumps(result, indent=2))
        for error in result.get("errors", []):
            print(f"adrafinil-agent-poll: {error}", file=sys.stderr)
        return 1 if result.get("errors") else 0
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"adrafinil-agent-poll: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
