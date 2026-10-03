#!/usr/bin/env python3
"""Isolated OS/daemon boundaries for the poller's subprocess integration tests."""

import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path
from unittest.mock import patch

STATE = Path(os.environ["POLL_TEST_STATE"])


def read():
    return json.loads(STATE.read_text())


def write(state):
    STATE.write_text(json.dumps(state))


def cli():
    state = read()
    args = sys.argv[2:]
    state.setdefault("calls", []).append(args)
    status = state["status"]
    warnings = ""
    if args[0] == "status":
        state["statusReads"] = state.get("statusReads", 0) + 1
        replacement = state.get("statusOnRead", {}).get(str(state["statusReads"]))
        if replacement is not None:
            status = state["status"] = replacement
        print(json.dumps(status))
    elif args[0] == "acquire":
        key = args[1]
        failure = state.get("failAcquire", {}).get(key)
        if failure == "refused":
            warnings = "acquire refused"
        else:
            pid = int(args[args.index("--pid") + 1])
            if failure == "pid-exited":
                pid = 999
                warnings = "requested PID exited; falling back to ancestor"
            hold = {"key": key, "pid": pid, "tool": args[args.index("--tool") + 1],
                    "origin": "hook", "expiresAt": 4000000000}
            status["assertions"] = [a for a in status["assertions"] if a["key"] != key] + [hold]
    elif args[0] == "release":
        key = args[1]
        removed = {key, state.get("removeOnRelease", {}).get(key)}
        status["assertions"] = [a for a in status["assertions"] if a["key"] not in removed]
        refreshed = state.get("refreshOnRelease", {}).get(key)
        if refreshed:
            for hold in status["assertions"]:
                if hold["key"] == refreshed:
                    hold["lastActivityAt"] += 60
    else:
        raise AssertionError(args)
    write(state)
    if warnings:
        print(warnings, file=sys.stderr)  # Real CLI returns 0 even on these errors.


def driver():
    script = Path(sys.argv[2])
    spec = importlib.util.spec_from_file_location("poller", script)
    poller = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(poller)
    real_run = subprocess.run

    def system_run(args, **kwargs):
        state = read()
        command = str(args[0])
        if command == "/bin/ps":
            stdout = state["ps"].replace("{self}", str(os.getpid())).replace("{uid}", str(os.getuid()))
            if "lstart=" not in args[-1]:
                stdout = "\n".join(" ".join((row[0], row[1], row[7])) for line in stdout.splitlines() if len(row := line.split(None, 7)) == 8)
        elif command == "/usr/bin/pmset":
            stdout = state["power"]
        elif command == "/usr/sbin/lsof":
            if state.get("lsofFailure"):
                raise subprocess.CalledProcessError(1, args)
            stdout = state.get("lsof", "")
        elif command == "/bin/launchctl":
            state.setdefault("launchctl", []).append(args[1:])
            code = 0
            if args[1] == "print":
                code = 0 if state.get("loaded") else 113
            elif args[1] == "bootout":
                state["loaded"] = False
            elif args[1] == "bootstrap":
                if state.get("failBootstrap"):
                    state["failBootstrap"] = False
                    code = 5
                else:
                    state["loaded"] = True
            write(state)
            if code and kwargs.get("check"):
                raise subprocess.CalledProcessError(code, args)
            return subprocess.CompletedProcess(args, code, "", "")
        else:
            # Only the explicitly installed fixture CLI may execute.
            assert command == str(Path.home() / ".local/bin/adrafinil"), args
            return real_run(args, **kwargs)
        return subprocess.CompletedProcess(args, 0, stdout, "")

    with patch.object(sys, "platform", "darwin"), patch.object(sys, "argv", [str(script), *sys.argv[3:]]), patch.object(subprocess, "run", side_effect=system_run):
        return poller.main()


if __name__ == "__main__":
    sys.exit(cli() if sys.argv[1] == "cli" else driver())
