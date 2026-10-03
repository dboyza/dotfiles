#!/usr/bin/env python3
"""Reconcile activity-only Adrafinil holds from a macOS LaunchAgent every minute."""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile


LABEL = "com.dboyza.adrafinil-agent-poll"
INTERVAL = 60
TTL = 180
APPLE_EPOCH = 978307200
SESSION_KEY = re.compile(r"^codex:([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})$")
KEY_PATTERN = re.compile(r"^(codex|claude-code):dotfiles-poll:[1-9][0-9]*$")
CODEX_ASSERTION = re.compile(
    r'^\s*pid (\d+)\(codex\):.*\bPreventUserIdleSystemSleep\b'
    r'.*named: "Codex is running an active turn"\s*$', re.MULTILINE
)


def run(args):
    result = subprocess.run(
        [str(arg) for arg in args], input="", text=True, capture_output=True,
        timeout=10, check=True,
    )
    # Adrafinil deliberately exits zero for failed hooks; stderr is significant.
    if result.stderr.strip():
        raise RuntimeError(result.stderr.strip())
    return result.stdout


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


def active_agents(process_map, assertions, sessions):
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
                return ("missing", None)
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
            timestamp = datetime.fromisoformat(record["timestamp"].replace("Z", "+00:00")).timestamp()
            return ("active" if kind == "task_started" else "idle", timestamp)
    except (OSError, ValueError, TypeError, KeyError, sqlite3.Error):
        pass
    return None


def stale_agent_holds(status, process_text, sessions, codex_home, now):
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
        if tool == "codex" and (match := SESSION_KEY.fullmatch(key)):
            activity = codex_session_state(codex_home, match[1])
            touched = entry.get("lastActivityAt", entry.get("acquiredAt"))
            if activity is None or type(touched) not in (int, float):
                continue
            touched += APPLE_EPOCH
            state, timestamp = activity
            if state == "missing" and now - touched >= INTERVAL:
                stale[key] = "session no longer exists in Codex's readable thread index"
            elif state == "idle" and timestamp >= touched:
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
                if type(updated) in (int, float) and type(touched) in (int, float) and updated / 1000 >= touched + APPLE_EPOCH:
                    stale[key] = "Claude session is idle"
    return stale


def hold_identity(entry):
    return tuple(entry.get(field) for field in ("pid", "origin", "acquiredAt", "lastActivityAt", "expiresAt"))


def release_hold(cli, key):
    try:
        run([cli, "release", key])
    except RuntimeError:
        # Stop hooks and the daemon's exit watcher may win the release race.
        latest = json.loads(run([cli, "status", "--json"]))
        if (
            isinstance(latest, dict) and isinstance(latest.get("assertions"), list)
            and not any(isinstance(entry, dict) and entry.get("key") == key for entry in latest["assertions"])
        ):
            return
        raise


def native_coverage(status, stale):
    """A valid native hold already protects this tool and process."""
    covered = set()
    now = datetime.now(timezone.utc).timestamp() - APPLE_EPOCH
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
        if expires is not None and (type(expires) not in (int, float) or expires <= now):
            continue
        covered.add((tool, pid))
    return covered


def reconcile(cli, active, status, dry_run=False, uncertain=(), stale=None):
    if not isinstance(status, dict):
        raise RuntimeError("Unrecognized Adrafinil status; no holds changed.")
    if status.get("daemonRunning") is False:
        raise RuntimeError("Adrafinil is not running; open the Adrafinil app.")
    if not isinstance(status.get("assertions"), list) or "paused" not in status:
        raise RuntimeError("Unrecognized Adrafinil status; no holds changed.")
    if status["paused"]:
        return {"paused": True, "active": active, "acquired": [], "released": []}
    stale = dict(stale or {})
    covered = native_coverage(status, stale)
    owned = {
        entry["key"] for entry in status["assertions"]
        if isinstance(entry, dict) and isinstance(entry.get("key"), str)
        and KEY_PATTERN.fullmatch(entry["key"])
    }
    if not dry_run and any(f"{tool}:dotfiles-poll:{pid}" in owned for tool, pid in covered):
        # Before handing an existing fallback over to a native hook, confirm the
        # hook is still present. If it vanished, renew the fallback instead.
        latest = json.loads(run([cli, "status", "--json"]))
        if not isinstance(latest, dict) or not isinstance(latest.get("assertions"), list) or "paused" not in latest:
            raise RuntimeError("Unrecognized Adrafinil status during native-hold recheck.")
        if latest["paused"]:
            return {"paused": True, "active": active, "acquired": [], "released": []}
        covered = native_coverage(latest, stale)
    desired = {
        f"{tool}:dotfiles-poll:{pid}": (pid, tool)
        for pid, tool in active.items() if (tool, pid) not in covered
    }
    # Acquire first so a handoff between agents never briefly drops our last hold.
    for key, (pid, tool) in sorted(desired.items()):
        if not dry_run:
            run([cli, "acquire", key, "--tool", tool, "--pid", pid,
                 "--ttl", TTL, "--reason", "Active work detected by the one-minute check"])
    # An unreadable Claude status is not proof of idle. Leave its existing lease
    # to expire without renewal, allowing the next tick to recover a partial read.
    released = sorted(
        key for key in owned - desired.keys()
        if int(key.rsplit(":", 1)[1]) not in uncertain
    )
    if stale and not dry_run:
        # A new turn may have refreshed a hold since detection. Do not release it
        # using the previous turn's evidence, or race a daemon restart.
        latest = json.loads(run([cli, "status", "--json"]))
        if not isinstance(latest, dict) or not isinstance(latest.get("assertions"), list):
            raise RuntimeError("Unrecognized Adrafinil status during stale-hold recheck.")
        before = {entry["key"]: entry for entry in status["assertions"] if isinstance(entry, dict) and "key" in entry}
        after = {entry["key"]: entry for entry in latest.get("assertions", []) if isinstance(entry, dict) and "key" in entry}
        stale = {
            key: reason for key, reason in stale.items()
            if not latest.get("paused") and latest.get("daemonBootID") == status.get("daemonBootID")
            and key in before and key in after and hold_identity(before[key]) == hold_identity(after[key])
        }
    released = sorted(set(released) | stale.keys())
    for key in released:
        if not dry_run:
            release_hold(cli, key)
    return {
        "paused": False, "active": active, "acquired": sorted(desired), "released": released,
        "staleReasons": stale,
        "coveredByNative": {pid: tool for pid, tool in active.items() if (tool, pid) in covered},
    }


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
        "StartInterval": INTERVAL,
        "ProcessType": "Background",
        "EnvironmentVariables": {"HOME": str(home)},
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
    if plist.exists():
        previous = plistlib.loads(plist.read_bytes())
        if previous.get("Label") != LABEL:
            raise RuntimeError(f"Refusing to replace unrelated LaunchAgent: {plist}")
    domain = f"gui/{os.getuid()}"
    loaded = subprocess.run(
        ["/bin/launchctl", "print", f"{domain}/{LABEL}"], capture_output=True,
        timeout=10,
    ).returncode == 0
    if loaded:
        run(["/bin/launchctl", "bootout", f"{domain}/{LABEL}"])
    atomic_write(plist, plistlib.dumps(definition))
    run(["/bin/launchctl", "bootstrap", domain, plist])
    print(f"Installed {plist}; checks every {INTERVAL} seconds while the Mac is awake.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install", action="store_true", help="Install and load the per-user LaunchAgent")
    parser.add_argument("--dry-run", action="store_true", help="Show detected activity and planned holds without changes")
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
        status = json.loads(run([cli, "status", "--json"]))
        process_text = run(["/bin/ps", "-axo", "pid=,uid=,comm="])
        snapshot = processes(process_text, os.getuid())
        active, uncertain = active_agents(snapshot, run(["/usr/bin/pmset", "-g", "assertions"]), Path.home() / ".claude/sessions")
        stale = stale_agent_holds(status, process_text, Path.home() / ".claude/sessions", Path.home() / ".codex", datetime.now(timezone.utc).timestamp())
        result = reconcile(cli, active, status, args.dry_run, uncertain, stale)
        result["uncertainPids"] = sorted(uncertain)
        result["checkedAt"] = datetime.now(timezone.utc).isoformat()
        if args.dry_run:
            print(json.dumps(result, indent=2))
        else:
            atomic_write(Path.home() / ".local/state/dotfiles/adrafinil-poll/status.json", json.dumps(result, indent=2).encode())
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"adrafinil-agent-poll: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
