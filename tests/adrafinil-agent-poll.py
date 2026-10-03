#!/usr/bin/env python3
"""Regression checks for missed active agents and accidental idle holds."""

import importlib.util
from contextlib import closing
import json
from pathlib import Path
import plistlib
import subprocess
import sqlite3
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

    def test_native_hook_already_covers_busy_agent_without_a_second_hold(self):
        status = {"paused": False, "assertions": [
            {"key": "claude-code:session-201", "pid": 201, "tool": "claude-code", "origin": "hook"},
        ]}
        with patch.object(poller, "run") as command:
            result = poller.reconcile("adrafinil", {201: "claude-code"}, status)
            self.assertEqual(result["acquired"], [])
            command.assert_not_called()

    def test_native_hook_takes_over_existing_fallback_without_releasing_native(self):
        for tool in ["claude-code", "codex"]:
            key = f"{tool}:dotfiles-poll:201"
            native = {"key": f"{tool}:session-201", "pid": 201, "tool": tool, "origin": "hook"}
            status = {"paused": False, "assertions": [native, {"key": key}]}
            with patch.object(poller, "run", side_effect=[json.dumps(status), ""]) as command:
                result = poller.reconcile("adrafinil", {201: tool}, status)
                self.assertEqual(result["acquired"], [])
                self.assertEqual(result["released"], [key])
                self.assertEqual(command.call_args_list[-1].args[0], ["adrafinil", "release", key])

    def test_disappearing_native_hook_retains_and_renews_fallback(self):
        key = "claude-code:dotfiles-poll:201"
        native = {"key": "claude-code:session", "pid": 201, "tool": "claude-code", "origin": "hook"}
        status = {"paused": False, "assertions": [native, {"key": key}]}
        latest = {"paused": False, "assertions": [{"key": key}]}
        with patch.object(poller, "run", side_effect=[json.dumps(latest), ""]) as command:
            result = poller.reconcile("adrafinil", {201: "claude-code"}, status)
            self.assertEqual(result["acquired"], [key])
            self.assertEqual(result["released"], [])
            self.assertEqual(command.call_count, 2)
            self.assertEqual(command.call_args_list[0].args[0], ["adrafinil", "status", "--json"])
            self.assertEqual(command.call_args_list[-1].args[0][1], "acquire")

    def test_other_sessions_manual_holds_and_stale_hooks_do_not_cover_agent(self):
        for native in [
            {"key": "claude-code:other", "pid": 202, "tool": "claude-code", "origin": "hook"},
            {"key": "hold:manual", "pid": 201, "tool": "claude-code", "origin": "manual"},
            {"key": "codex:other", "pid": 201, "tool": "codex", "origin": "hook"},
            {"key": "claude-code:expired", "pid": 201, "tool": "claude-code", "origin": "hook", "expiresAt": 0},
        ]:
            status = {"paused": False, "assertions": [native]}
            with patch.object(poller, "run", return_value="") as command:
                result = poller.reconcile("adrafinil", {201: "claude-code"}, status)
                self.assertEqual(result["acquired"], ["claude-code:dotfiles-poll:201"])
                self.assertEqual(command.call_args.args[0][1], "acquire")
        native = {"key": "claude-code:stale", "pid": 201, "tool": "claude-code", "origin": "hook"}
        status = {"paused": False, "assertions": [native]}
        result = poller.reconcile("adrafinil", {201: "claude-code"}, status, dry_run=True, stale={native["key"]: "stale"})
        self.assertEqual(result["acquired"], ["claude-code:dotfiles-poll:201"])

    def test_only_uncovered_session_gets_fallback(self):
        status = {"paused": False, "assertions": [
            {"key": "claude-code:session-201", "pid": 201, "tool": "claude-code", "origin": "hook"},
        ]}
        with patch.object(poller, "run", return_value="") as command:
            result = poller.reconcile("adrafinil", {201: "claude-code", 202: "claude-code"}, status)
            self.assertEqual(result["acquired"], ["claude-code:dotfiles-poll:202"])
            self.assertEqual(command.call_count, 1)

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


class StaleHoldTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.thread = "01a0fe08-edc8-7c70-813f-6f134930653f"
        self.key = "codex:" + self.thread
        self.hold = {"key": self.key, "tool": "codex", "origin": "hook", "pid": 5010,
                     "acquiredAt": 100, "lastActivityAt": 100, "expiresAt": 86500}
        self.status = {"paused": False, "daemonBootID": "boot-1", "assertions": [self.hold]}
        self.processes = "5010 501 /a/codex\n"
        self.now = poller.APPLE_EPOCH + 300
        with closing(sqlite3.connect(self.home / "state_5.sqlite")) as connection, connection:
            connection.execute("CREATE TABLE threads (id TEXT, rollout_path TEXT)")

    def lifecycle(self, *events):
        path = self.home / "session.jsonl"
        lines = []
        for kind, seconds in events:
            timestamp = poller.datetime.fromtimestamp(poller.APPLE_EPOCH + seconds, poller.timezone.utc).isoformat()
            lines.append(json.dumps({"type": "event_msg", "timestamp": timestamp, "payload": {"type": kind}}))
        path.write_text("\n".join(lines) + "\n")
        with closing(sqlite3.connect(self.home / "state_5.sqlite")) as connection, connection:
            connection.execute("DELETE FROM threads")
            connection.execute("INSERT INTO threads VALUES (?, ?)", (self.thread, str(path)))
        return path

    def detect(self):
        return poller.stale_agent_holds(self.status, self.processes, self.home, self.home, self.now)

    def test_removed_session_is_stale_even_though_shared_server_is_alive(self):
        self.assertIn(self.key, self.detect())
        with patch.object(poller, "run", side_effect=[json.dumps(self.status), ""]) as command:
            result = poller.reconcile("adrafinil", {}, self.status, stale=self.detect())
            self.assertEqual(result["released"], [self.key])
            self.assertEqual(command.call_args_list[-1].args[0], ["adrafinil", "release", self.key])

    def test_new_unindexed_session_gets_time_to_initialize(self):
        self.now = poller.APPLE_EPOCH + 120
        self.assertEqual(self.detect(), {})

    def test_completed_and_interrupted_turns_release_without_process_exit(self):
        for event in ["task_complete", "turn_aborted"]:
            self.lifecycle(("task_started", 100), (event, 150))
            self.assertIn(self.key, self.detect())

    def test_new_turn_and_new_hook_are_not_released_using_old_completion(self):
        self.lifecycle(("task_complete", 150), ("task_started", 160))
        self.assertEqual(self.detect(), {})
        self.lifecycle(("task_complete", 150))
        self.hold["lastActivityAt"] = 160
        self.assertEqual(self.detect(), {})

    def test_unreadable_index_transcript_and_partial_records_are_unknown(self):
        path = self.lifecycle(("task_complete", 150))
        with path.open("a") as stream:
            stream.write('{"type":"event_msg"')
        self.assertEqual(self.detect(), {})
        path.unlink()
        self.assertEqual(self.detect(), {})
        (self.home / "state_5.sqlite").write_text("not a database")
        self.assertEqual(self.detect(), {})
        (self.home / "state_5.sqlite").unlink()
        self.assertEqual(self.detect(), {})

    def test_unindexed_rollout_is_checked_before_declaring_session_removed(self):
        path = self.lifecycle(("task_started", 100))
        archived = self.home / "archived_sessions" / f"rollout-2001-01-01-{self.thread}.jsonl"
        archived.parent.mkdir()
        path.rename(archived)
        with closing(sqlite3.connect(self.home / "state_5.sqlite")) as connection, connection:
            connection.execute("DELETE FROM threads")
        self.assertEqual(self.detect(), {})

    def test_dead_native_agent_is_cleaned_but_manual_and_other_tools_survive(self):
        self.processes = "999 501 /a/other\n"
        self.status["assertions"] += [
            dict(self.hold, key="hold:manual", origin="manual"),
            dict(self.hold, key="pi:session", tool="pi"),
            dict(self.hold, key="codex:explicit", origin="manual"),
            dict(self.hold, key="codex:dotfiles-poll:5010"),
        ]
        self.assertEqual(list(self.detect()), [self.key])

    def test_claude_idle_needs_matching_session_and_status_newer_than_hook(self):
        self.hold.update(key="claude-code:session", tool="claude-code")
        path = self.home / "5010.json"
        status = {"pid": 5010, "sessionId": "session", "status": "idle",
                  "statusUpdatedAt": (poller.APPLE_EPOCH + 150) * 1000}
        path.write_text(json.dumps(status))
        self.assertIn(self.hold["key"], self.detect())
        for changes in [{"status": "busy"}, {"status": "waiting"}, {"sessionId": "other"},
                        {"statusUpdatedAt": (poller.APPLE_EPOCH + 90) * 1000}]:
            path.write_text(json.dumps({**status, **changes}))
            self.assertEqual(self.detect(), {})

    def test_refreshed_hold_paused_daemon_and_restarted_daemon_cancel_release(self):
        stale = self.detect()
        for latest in [
            {**self.status, "assertions": [dict(self.hold, lastActivityAt=200)]},
            {**self.status, "paused": True},
            {**self.status, "daemonBootID": "boot-2"},
            {**self.status, "assertions": []},
        ]:
            with patch.object(poller, "run", return_value=json.dumps(latest)) as command:
                self.assertEqual(poller.reconcile("adrafinil", {}, self.status, stale=stale)["released"], [])
                command.assert_called_once_with(["adrafinil", "status", "--json"])

    def test_dry_run_reports_native_cleanup_without_writes(self):
        with patch.object(poller, "run") as command:
            result = poller.reconcile("adrafinil", {}, self.status, dry_run=True, stale=self.detect())
            self.assertEqual(result["released"], [self.key])
            command.assert_not_called()

    def test_native_stop_hook_winning_release_race_is_success(self):
        with patch.object(poller, "run", side_effect=[RuntimeError("unknown key"), json.dumps({"assertions": []})]):
            poller.release_hold("adrafinil", self.key)

    def test_real_release_failure_is_still_reported(self):
        with patch.object(poller, "run", side_effect=[RuntimeError("release refused"), json.dumps(self.status)]):
            with self.assertRaisesRegex(RuntimeError, "release refused"):
                poller.release_hold("adrafinil", self.key)


if __name__ == "__main__":
    unittest.main()
