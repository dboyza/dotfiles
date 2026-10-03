#!/usr/bin/env python3
"""Run the production entrypoint and CLI subprocesses with an isolated home.

Only macOS process/power/socket/launchctl snapshots and the Adrafinil daemon are
substituted. Parsing, SQLite, lifecycle files, locking, CLI error handling,
installation, state persistence, and command-line arguments run unchanged.
"""

import json
import os
import plistlib
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DRIVER = ROOT / "tests/fixtures/adrafinil-poll-driver.py"
SCRIPT = ROOT / "scripts/adrafinil-agent-poll.py"
THREAD = "00000000-0000-0000-0000-000000000001"
NATIVE = "codex:" + THREAD
CLAUDE = "claude-code:session-201"
EPOCH = 978307200
BORN = datetime(2026, 10, 1, tzinfo=timezone.utc).timestamp()
TOUCHED = BORN - EPOCH + 60
POWER = 'Assertion status system-wide:\nListed by owning process:\n   pid 101(codex): [0x1] 00:01:00 PreventUserIdleSystemSleep named: "Codex is running an active turn"\n'


def hold(key, pid, tool="codex", **extra):
    return {"key": key, "pid": pid, "tool": tool, "origin": "hook",
            "acquiredAt": TOUCHED, "lastActivityAt": TOUCHED, **extra}


@unittest.skipUnless(os.name == "posix", "macOS-only poller requires POSIX locks")
class PollIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="adrafinil-test-")
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.env = {**os.environ, "HOME": str(self.home), "PYTHONDONTWRITEBYTECODE": "1"}
        for name in ("CODEX_HOME", "CLAUDE_CONFIG_DIR"):
            self.env.pop(name, None)
        self.state_file = self.home / "daemon.json"
        self.env["POLL_TEST_STATE"] = str(self.state_file)
        self.cli = self.home / ".local/bin/adrafinil"
        self.cli.parent.mkdir(parents=True)
        self.cli.write_text(f"#!{sys.executable}\nimport runpy, sys\nsys.argv.insert(1, 'cli')\nrunpy.run_path({str(DRIVER)!r}, run_name='__main__')\n")
        self.cli.chmod(0o700)
        born = datetime.fromtimestamp(BORN, timezone.utc).astimezone().strftime("%a %b %d %H:%M:%S %Y")
        self.state = {"status": {"paused": False, "daemonBootID": "boot-1", "assertions": []},
                      "ps": f"{{self}} {{uid}} {born} python\n101 {{uid}} {born} /a/codex\n301 {{uid}} {born} /a/codex\n201 {{uid}} {born} /a/claude\n",
                      "power": POWER}
        self.result_path = self.home / ".local/state/dotfiles/adrafinil-poll/status.json"
        self.plist = self.home / "Library/LaunchAgents/com.dboyza.adrafinil-agent-poll.plist"

    def invoke(self, *args, expected=0):
        self.state_file.write_text(json.dumps(self.state))
        result = subprocess.run([sys.executable, "-B", "-W", "error::ResourceWarning", str(DRIVER), "poll", str(SCRIPT), *args],
                                env=self.env, text=True, capture_output=True, timeout=15, check=False)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        self.state = json.loads(self.state_file.read_text())
        return result

    def keys(self):
        return {a["key"] for a in self.state["status"]["assertions"]}

    def mutations(self):
        return [c for c in self.state.get("calls", []) if c[0] != "status"]

    def claude(self, status="busy", **extra):
        root = Path(self.env.get("CLAUDE_CONFIG_DIR", self.home / ".claude")) / "sessions"
        root.mkdir(parents=True, exist_ok=True)
        (root / "201.json").write_text(json.dumps({"pid": 201, "sessionId": "session-201", "status": status,
                                                  "startedAt": BORN * 1000, "statusUpdatedAt": (BORN + 120) * 1000, **extra}))

    def rollout(self, event="task_complete", timestamp=None):
        root = Path(self.env.get("CODEX_HOME", self.home / ".codex"))
        root.mkdir(parents=True, exist_ok=True)
        path = root / "rollout.jsonl"
        path.write_text(json.dumps({"type": "event_msg", "timestamp": timestamp if timestamp is not None else datetime.fromtimestamp(BORN + 120, timezone.utc).isoformat(),
                                    "payload": {"type": event}}) + "\n")
        with closing(sqlite3.connect(root / "state_5.sqlite")) as connection, connection:
            connection.execute("CREATE TABLE IF NOT EXISTS threads (id TEXT, rollout_path TEXT)")
            connection.execute("DELETE FROM threads")
            connection.execute("INSERT INTO threads VALUES (?, ?)", (THREAD, str(path)))

    def test_busy_then_idle_and_exit_preserve_manual_holds(self):
        self.state["status"]["assertions"] = [hold("hold:manual", 900, origin="manual")]
        self.claude()
        self.invoke()
        self.assertEqual(self.keys(), {"codex:dotfiles-poll:101", "claude-code:dotfiles-poll:201", "hold:manual"})
        for call in self.mutations():
            self.assertEqual(call[call.index("--ttl") + 1], "180")
        self.state["power"] = "Assertion status system-wide:\nNo assertions.\n"
        self.claude("idle")
        self.invoke()
        self.assertEqual(self.keys(), {"hold:manual"})

    def test_native_hooks_cover_claude_and_codex_socket_client(self):
        self.claude()
        self.state["lsof"] = "p101\nf35\nd0xa\nn->0xb\np301\nf62\nd0xb\nn/private/tmp/codex-daemon-501/abcd\n"
        self.state["status"]["assertions"] = [hold(NATIVE, 301), hold(CLAUDE, 201, "claude-code"),
                                               hold("codex:dotfiles-poll:101", 101), hold("claude-code:dotfiles-poll:201", 201, "claude-code")]
        self.invoke()
        self.assertEqual(self.keys(), {NATIVE, CLAUDE})
        report = json.loads(self.result_path.read_text())
        self.assertEqual(report["coveredByNative"], {"101": "codex", "201": "claude-code"})
        self.assertEqual([c[0] for c in self.mutations()], ["release", "release"])

    def test_socket_failure_keeps_fallback_protection(self):
        self.state["status"]["assertions"] = [hold(NATIVE, 301)]
        self.state["lsofFailure"] = True
        self.invoke()
        self.assertEqual(self.keys(), {NATIVE, "codex:dotfiles-poll:101"})
        self.assertTrue(json.loads(self.result_path.read_text())["warnings"])

    def test_native_expiring_before_next_tick_does_not_suppress_fallback(self):
        expires = datetime.now(timezone.utc).timestamp() - EPOCH + 15
        self.state["status"]["assertions"] = [hold(NATIVE, 101, expiresAt=expires)]
        self.invoke()
        self.assertEqual(self.keys(), {NATIVE, "codex:dotfiles-poll:101"})

    def test_native_disappearing_during_handoff_renews_existing_fallback(self):
        fallback = hold("codex:dotfiles-poll:101", 101)
        self.state["status"]["assertions"] = [hold(NATIVE, 101), fallback]
        self.state["statusOnRead"] = {"2": {**self.state["status"], "assertions": [fallback]}}
        self.invoke()
        self.assertEqual(self.keys(), {fallback["key"]})
        self.assertEqual([c[0] for c in self.mutations()], ["acquire"])

    def test_second_handoff_rechecks_after_first_release(self):
        self.claude()
        codex_fallback = "codex:dotfiles-poll:101"
        claude_fallback = "claude-code:dotfiles-poll:201"
        self.state["status"]["assertions"] = [hold(NATIVE, 101), hold(CLAUDE, 201, "claude-code"),
                                               hold(codex_fallback, 101), hold(claude_fallback, 201, "claude-code")]
        self.state["removeOnRelease"] = {claude_fallback: NATIVE}
        self.invoke()
        self.assertEqual(self.keys(), {CLAUDE, codex_fallback})
        self.assertEqual([c[0] for c in self.mutations()], ["release", "acquire"])

    def test_custom_homes_completed_codex_and_idle_claude_are_cleaned(self):
        self.env.update(CODEX_HOME=str(self.home / "custom codex"), CLAUDE_CONFIG_DIR=str(self.home / "custom claude"))
        self.rollout()
        self.claude("idle")
        self.state["status"]["assertions"] = [hold(NATIVE, 301), hold(CLAUDE, 201, "claude-code")]
        self.invoke()
        self.assertEqual(self.keys(), {"codex:dotfiles-poll:101"})

    def test_later_hold_refresh_is_rechecked_after_first_release(self):
        self.state["power"] = "Assertion status system-wide:\nNo assertions.\n"
        self.state["status"]["assertions"] = [hold("codex:a", 800), hold("codex:b", 801)]
        self.state["refreshOnRelease"] = {"codex:a": "codex:b"}
        self.invoke()
        self.assertEqual(self.keys(), {"codex:b"})

    def test_pid_reuse_cannot_make_stale_claude_busy(self):
        self.claude(startedAt=(BORN - 3600) * 1000)
        self.state["status"]["assertions"] = [hold(CLAUDE, 201, "claude-code", lastActivityAt=TOUCHED - 3600)]
        self.invoke()
        self.assertEqual(self.keys(), {"codex:dotfiles-poll:101"})
        self.assertIn(201, json.loads(self.result_path.read_text())["uncertainPids"])

    def test_one_failed_acquire_does_not_block_other_active_agents_or_remove_native(self):
        self.rollout()
        self.claude()
        self.state["status"]["assertions"] = [hold(NATIVE, 301)]
        self.state["failAcquire"] = {"claude-code:dotfiles-poll:201": "refused"}
        self.invoke(expected=1)
        self.assertEqual(self.keys(), {NATIVE, "codex:dotfiles-poll:101"})
        self.assertEqual(json.loads(self.result_path.read_text())["acquired"], ["codex:dotfiles-poll:101"])

    def test_cli_warning_with_wrong_ancestor_pid_is_cleaned_and_reported(self):
        self.state["failAcquire"] = {"codex:dotfiles-poll:101": "pid-exited"}
        result = self.invoke(expected=1)
        self.assertEqual(self.keys(), set())
        self.assertIn("requested PID exited", result.stderr)

    def test_invalid_snapshots_never_mutate_registry(self):
        original = json.loads(json.dumps(self.state))
        for change in ({"power": "garbage"}, {"ps": ""}, {"ps": "broken"}, {"status": []},
                       {"status": {"assertions": [], "paused": "false"}},
                       {"status": {"assertions": [None], "paused": False}},
                       {"status": {"assertions": [hold(NATIVE, 301, expiresAt="soon")], "paused": False}}):
            with self.subTest(change=change):
                self.state = {**original, **change}
                self.invoke(expected=1)
                self.assertEqual(self.mutations(), [])

    def test_unknown_lifecycle_metadata_preserves_native_hold(self):
        self.state["status"]["assertions"] = [hold(NATIVE, 301)]
        for timestamp in (42, "bad", "2026-10-01T00:02:00"):
            with self.subTest(timestamp=timestamp):
                self.rollout(timestamp=timestamp)
                self.invoke()
                self.assertIn(NATIVE, self.keys())

    def test_pause_and_dry_run_leave_daemon_unchanged(self):
        self.claude()
        self.invoke("--dry-run")
        self.assertEqual(self.mutations(), [])
        self.assertFalse(self.result_path.parent.exists())
        self.state["status"]["paused"] = True
        self.invoke()
        self.assertEqual(self.mutations(), [])

    def test_overlapping_invocation_exits_without_reading_or_writing_daemon(self):
        import fcntl
        self.result_path.parent.mkdir(parents=True)
        with (self.result_path.parent / "poll.lock").open("a") as stream:
            fcntl.flock(stream, fcntl.LOCK_EX)
            self.invoke()
            self.assertEqual(self.state.get("calls", []), [])
            self.assertFalse(self.result_path.exists())

    def test_install_preserves_custom_homes_and_failed_upgrade_restores_old_job(self):
        self.env.update(CODEX_HOME=str(self.home / "custom codex"))
        self.invoke("--install")
        old = self.plist.read_bytes()
        definition = plistlib.loads(old)
        self.assertEqual(definition["StartInterval"], 60)
        self.assertEqual(definition["EnvironmentVariables"]["CODEX_HOME"], self.env["CODEX_HOME"])
        self.state["failBootstrap"] = True
        self.invoke("--install", expected=1)
        self.assertEqual(self.plist.read_bytes(), old)
        self.assertTrue(self.state["loaded"])

    def test_failed_first_install_removes_new_plist(self):
        self.state["failBootstrap"] = True
        self.invoke("--install", expected=1)
        self.assertFalse(self.plist.exists())

    def test_install_refuses_unrelated_or_unrecoverable_loaded_job(self):
        self.state["loaded"] = True
        self.invoke("--install", expected=1)
        self.assertEqual([c[0] for c in self.state["launchctl"]], ["print"])
        self.plist.parent.mkdir(parents=True)
        original = plistlib.dumps({"Label": "another-job"})
        self.plist.write_bytes(original)
        self.state["launchctl"] = []
        self.invoke("--install", expected=1)
        self.assertEqual(self.plist.read_bytes(), original)
        self.assertEqual(self.state["launchctl"], [])

    def test_dry_run_install_combination_is_rejected_without_installation(self):
        self.invoke("--install", "--dry-run", expected=2)
        self.assertFalse(self.plist.exists())
        self.assertEqual(self.state.get("launchctl", []), [])


if __name__ == "__main__":
    unittest.main()
