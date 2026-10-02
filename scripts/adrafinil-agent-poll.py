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
import subprocess
import sys
import tempfile


LABEL = "com.dboyza.adrafinil-agent-poll"
INTERVAL = 60
TTL = 180
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


def reconcile(cli, active, status, dry_run=False, uncertain=()):
    if not isinstance(status, dict):
        raise RuntimeError("Unrecognized Adrafinil status; no holds changed.")
    if status.get("daemonRunning") is False:
        raise RuntimeError("Adrafinil is not running; open the Adrafinil app.")
    if not isinstance(status.get("assertions"), list) or "paused" not in status:
        raise RuntimeError("Unrecognized Adrafinil status; no holds changed.")
    if status["paused"]:
        return {"paused": True, "active": active, "acquired": [], "released": []}
    desired = {f"{tool}:dotfiles-poll:{pid}": (pid, tool) for pid, tool in active.items()}
    owned = {
        entry["key"] for entry in status["assertions"]
        if isinstance(entry, dict) and isinstance(entry.get("key"), str)
        and KEY_PATTERN.fullmatch(entry["key"])
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
    for key in released:
        if not dry_run:
            run([cli, "release", key])
    return {"paused": False, "active": active, "acquired": sorted(desired), "released": released}


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
        snapshot = processes(run(["/bin/ps", "-axo", "pid=,uid=,comm="]), os.getuid())
        active, uncertain = active_agents(snapshot, run(["/usr/bin/pmset", "-g", "assertions"]), Path.home() / ".claude/sessions")
        result = reconcile(cli, active, status, args.dry_run, uncertain)
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
