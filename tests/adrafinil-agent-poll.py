#!/usr/bin/env python3
"""Regression checks for missed active agents and accidental idle holds."""

import importlib.util
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/adrafinil-agent-poll.py"
SPEC = importlib.util.spec_from_file_location("poller", SCRIPT)
poller = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(poller)

PMSET = '''Assertion status system-wide:
   PreventUserIdleSystemSleep 1
Listed by owning process:
   pid 101(codex): [0x000001] 00:03:22 PreventUserIdleSystemSleep named: "Codex is running an active turn"
   pid 102(codex): [0x000002] 00:01:11 PreventUserIdleSystemSleep named: "something else"
   pid 103(caffeinate): [0x000003] 00:02:11 PreventUserIdleSystemSleep named: "Codex is running an active turn"
   pid 104(codex): [0x000004] 00:02:11 PreventUserIdleSystemSleep named: "Codex is running an active turn"
'''


class PollTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.sessions = Path(self.temporary.name)

    def session(self, pid, status, **extra):
        data = {"pid": pid, "sessionId": f"session-{pid}", "status": status, **extra}
        (self.sessions / f"{pid}.json").write_text(json.dumps(data))

    def test_process_identity_excludes_other_users_helpers_and_prompt_text(self):
        snapshot = poller.processes('''
101 501 /a/version/bin/codex
102 501 codex
103 501 caffeinate
104 502 codex
201 501 /Users/person/.local/share/claude/versions/2.1.286
202 501 claude
203 501 /a/claude/2.1.286-build/claude
204 501 claude bg-spare
205 501 /a/codex-code-mode-host
206 501 /a/project/claude/server
''', 501)
        self.assertEqual(snapshot, {101: "codex", 102: "codex", 201: "claude-code", 202: "claude-code", 203: "claude-code"})
        self.assertEqual(poller.active_agents(snapshot, PMSET, self.sessions), ({101: "codex"}, {201, 202, 203}))

    def test_claude_busy_only_and_stale_pid_files_are_ignored(self):
        for pid, status in [(201, "busy"), (202, "idle"), (203, "waiting"), (204, "busy"), (205, "unknown")]:
            self.session(pid, status)
        snapshot = {pid: "claude-code" for pid in [201, 202, 203, 205]}
        snapshot[204] = "codex"
        self.assertEqual(poller.active_agents(snapshot, "", self.sessions), ({201: "claude-code"}, {205}))

    def test_malformed_partial_mismatched_and_auth_files_are_ignored(self):
        (self.sessions / "201.json").write_text('{"pid":')
        (self.sessions / "202.json").write_text('[]')
        (self.sessions / "203.json").write_text(json.dumps({"pid": 204, "status": "busy", "sessionId": "x"}))
        (self.sessions / "205.secret.key").write_text("not a status file")
        self.session(206, "busy", sessionId="")
        snapshot = {pid: "claude-code" for pid in range(201, 207)}
        self.assertEqual(poller.active_agents(snapshot, "", self.sessions), ({}, set(range(201, 207))))

    def test_missing_claude_directory_still_detects_codex(self):
        self.assertEqual(poller.active_agents({101: "codex"}, PMSET, self.sessions / "absent"), ({101: "codex"}, set()))

    def test_partial_status_keeps_existing_lease_without_renewing_it(self):
        status = {"paused": False, "assertions": [{"key": "claude-code:dotfiles-poll:201"}]}
        with patch.object(poller, "run") as command:
            poller.reconcile("adrafinil", {}, status, uncertain={201})
            command.assert_not_called()
            poller.reconcile("adrafinil", {}, status)
            command.assert_called_once_with(["adrafinil", "release", "claude-code:dotfiles-poll:201"])

    def test_empty_registry_acquires_then_idle_releases_only_our_hold(self):
        key = "codex:dotfiles-poll:101"
        status = {"paused": False, "isBlocking": False, "assertions": []}
        with patch.object(poller, "run", return_value="") as command:
            poller.reconcile("adrafinil", {101: "codex"}, status)
            args = command.call_args.args[0]
            self.assertEqual(args[:3], ["adrafinil", "acquire", key])
            self.assertEqual(args[args.index("--pid") + 1], 101)
            self.assertEqual(args[args.index("--ttl") + 1], 180)
            status["assertions"] = [{"key": key}, {"key": "codex:user-session"}, {"key": "hold:manual"}]
            command.reset_mock()
            poller.reconcile("adrafinil", {}, status)
            command.assert_called_once_with(["adrafinil", "release", key])

    def test_refresh_and_handoff_acquire_before_release(self):
        status = {"paused": False, "assertions": [{"key": "codex:dotfiles-poll:101"}]}
        with patch.object(poller, "run", return_value="") as command:
            poller.reconcile("adrafinil", {101: "codex"}, status)
            self.assertEqual(command.call_args.args[0][1], "acquire")
            command.reset_mock()
            poller.reconcile("adrafinil", {201: "claude-code"}, status)
            self.assertEqual([call.args[0][1] for call in command.call_args_list], ["acquire", "release"])

    def test_pause_and_dry_run_never_write(self):
        with patch.object(poller, "run") as command:
            poller.reconcile("adrafinil", {101: "codex"}, {"paused": True, "assertions": []})
            poller.reconcile("adrafinil", {101: "codex"}, {"paused": False, "assertions": []}, dry_run=True)
            command.assert_not_called()

    def test_missing_daemon_and_unknown_status_never_write(self):
        with patch.object(poller, "run") as command:
            for status in [[], {"daemonRunning": False}, {}, {"paused": False, "assertions": None}]:
                with self.assertRaises(RuntimeError):
                    poller.reconcile("adrafinil", {101: "codex"}, status)
            command.assert_not_called()

    def test_soft_cli_errors_are_not_reported_as_success(self):
        with patch.object(poller.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "", "acquire refused: paused")):
            with self.assertRaisesRegex(RuntimeError, "acquire refused"):
                poller.run(["adrafinil", "acquire"])

    def test_launchagent_runs_every_minute_without_waking_a_sleeping_mac(self):
        definition = poller.launch_agent(Path("/Users/With Spaces"), "/opt/homebrew/bin/python3", SCRIPT, "/a/Adrafinil.app/cli")
        loaded = plistlib.loads(plistlib.dumps(definition))
        self.assertEqual(loaded["StartInterval"], 60)
        self.assertTrue(loaded["RunAtLoad"])
        self.assertEqual(loaded["ProgramArguments"][-2:], ["--cli", "/a/Adrafinil.app/cli"])
        self.assertNotIn("KeepAlive", loaded)
        self.assertNotIn("StartCalendarInterval", loaded)

    def test_non_macos_is_a_noop(self):
        with patch.object(poller.sys, "platform", "win32"), patch.object(poller.sys, "argv", [str(SCRIPT)]), patch.object(poller, "run") as command:
            self.assertEqual(poller.main(), 0)
            command.assert_not_called()


if __name__ == "__main__":
    unittest.main()
