#!/usr/bin/env python3
"""Exercise app installation with temporary bundles and fake package commands."""

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


INSTALLER = Path(__file__).resolve().parents[1] / "scripts/install-macos-apps.py"
spec = importlib.util.spec_from_file_location("install_macos_apps", INSTALLER)
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class MacOSAppsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="dotfiles-apps-test-")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.home = self.base / "home"
        self.destination = self.home / "Applications"
        self.system = self.base / "Applications"
        self.destination.mkdir(parents=True)
        self.system.mkdir()
        self.log = self.base / "commands.jsonl"
        self.manifest = self.base / "manifest.json"
        self.chrome = {"bundle": "Google Chrome.app", "id": "com.google.Chrome", "cask": "google-chrome"}
        self.vscode = {"bundle": "Visual Studio Code.app", "id": "com.microsoft.VSCode", "cask": "visual-studio-code"}
        self.wallper = {"bundle": "Wallper.app", "id": "com.wallper.test", "url": "https://example.invalid/Wallper.zip", "minimum_macos": "14.0", "sha256": "0" * 64}
        self.brew = self.command("brew", '''
import json, os, pathlib, plistlib, sys
with open(os.environ["TEST_COMMAND_LOG"], "a") as log:
    log.write(json.dumps({"args": sys.argv[1:], "home": os.environ["HOME"],
        "no_update": os.environ.get("HOMEBREW_NO_AUTO_UPDATE"),
        "no_cleanup": os.environ.get("HOMEBREW_NO_INSTALL_CLEANUP")}) + "\\n")
if os.environ.get("TEST_BREW_FAIL"):
    sys.exit(23)
apps = json.loads(pathlib.Path(os.environ["TEST_MANIFEST"]).read_text())
app = next(app for app in apps if app.get("cask") == sys.argv[-1])
destination = pathlib.Path(sys.argv[sys.argv.index("--appdir") + 1])
contents = destination / app["bundle"] / "Contents"
contents.mkdir(parents=True)
with (contents / "Info.plist").open("wb") as output:
    plistlib.dump({"CFBundleIdentifier": app["id"], "CFBundleShortVersionString": "1.0"}, output)
''')
        self.spotlight = self.command("mdfind", '''
import os, sys
sys.stdout.buffer.write(os.fsencode(os.environ.get("TEST_SPOTLIGHT", "")))
''')

    def command(self, name, source):
        path = self.base / name
        path.write_text("#!" + sys.executable + "\n" + source)
        path.chmod(0o755)
        return path

    def bundle(self, path, app, version="0.0.1"):
        contents = path / "Contents"
        contents.mkdir(parents=True)
        with (contents / "Info.plist").open("wb") as output:
            plistlib.dump({"CFBundleIdentifier": app["id"], "CFBundleShortVersionString": version}, output)
        (contents / "payload").write_bytes(b"existing app must remain unchanged")
        return path

    def run_cli(self, apps, extra=(), environment=None):
        self.manifest.write_text(json.dumps(apps))
        env = dict(os.environ, TEST_COMMAND_LOG=str(self.log), TEST_MANIFEST=str(self.manifest))
        env.update(environment or {})
        return subprocess.run([
            sys.executable, str(INSTALLER), "--manifest", str(self.manifest),
            "--home", str(self.home), "--brew", str(self.brew),
            "--applications-root", str(self.system),
            "--applications-root", str(self.destination),
            "--spotlight", str(self.spotlight), *extra,
        ], env=env, capture_output=True, text=True)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_existing_manual_renamed_and_old_apps_are_unchanged(self):
        paths = [
            self.bundle(self.system / self.chrome["bundle"], self.chrome, "1.0"),
            self.bundle(self.destination / "Editors" / "My Editor.app", self.vscode, "0.1"),
            self.bundle(self.destination / self.wallper["bundle"], self.wallper, "99.0"),
        ]
        before = {path: (path / "Contents/Info.plist").read_bytes() for path in paths}
        result = self.run_cli([self.chrome, self.vscode, self.wallper])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [])
        self.assertEqual(result.stdout.count("Skipping"), 3)
        for path in paths:
            self.assertEqual((path / "Contents/Info.plist").read_bytes(), before[path])
            self.assertEqual((path / "Contents/payload").read_bytes(), b"existing app must remain unchanged")

    def test_missing_cask_installs_once_and_preserves_existing_app(self):
        self.bundle(self.system / self.chrome["bundle"], self.chrome)
        apps = [self.chrome, self.vscode]
        first = self.run_cli(apps)
        self.assertEqual(first.returncode, 0, first.stderr)
        calls = self.calls()
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0]["args"], ["install", "--cask", "--appdir", str(self.destination), self.vscode["cask"]])
        self.assertEqual(calls[0]["home"], str(self.home))
        self.assertEqual(calls[0]["no_update"], "1")
        self.assertEqual(calls[0]["no_cleanup"], "1")
        second = self.run_cli(apps)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(self.calls(), calls)

    def test_spotlight_live_renamed_bundle_skips_install(self):
        external = self.bundle(self.base / "external" / "Personal Browser.app", self.chrome)
        result = self.run_cli([self.chrome], environment={"TEST_SPOTLIGHT": str(external)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [])
        self.assertIn(str(external), result.stdout)

    def test_spotlight_stale_path_does_not_hide_missing_app(self):
        result = self.run_cli([self.chrome], environment={"TEST_SPOTLIGHT": str(self.base / "deleted.app")})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.calls()), 1)

    def test_spotlight_wrong_bundle_identity_does_not_skip(self):
        unrelated = self.bundle(self.base / "Unrelated.app", self.vscode)
        result = self.run_cli([self.chrome], environment={"TEST_SPOTLIGHT": str(unrelated)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.calls()), 1)

    def test_legacy_bundle_survives_nix_cleanup_without_version_change(self):
        old = self.bundle(self.system / "Nix Apps" / self.wallper["bundle"], self.wallper, "0.5")
        contents = (old / "Contents/Info.plist").read_bytes()
        payload = old / "Contents/payload"
        payload.chmod(0o444)
        result = self.run_cli([self.wallper], extra=["--preserve-legacy"])
        self.assertEqual(result.returncode, 0, result.stderr)
        shutil.rmtree(old)
        saved = self.destination / self.wallper["bundle"]
        self.assertEqual((saved / "Contents/Info.plist").read_bytes(), contents)
        self.assertTrue((saved / "Contents/payload").stat().st_mode & 0o200)
        second = self.run_cli([self.wallper])
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(self.calls(), [])

    def test_legacy_preservation_never_replaces_existing_destination(self):
        self.bundle(self.system / "Nix Apps" / self.wallper["bundle"], self.wallper, "0.5")
        current = self.bundle(self.destination / self.wallper["bundle"], self.wallper, "2.0")
        before = (current / "Contents/Info.plist").read_bytes()
        result = self.run_cli([self.wallper], extra=["--preserve-legacy"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((current / "Contents/Info.plist").read_bytes(), before)

    def test_zip_checksum_failure_does_not_extract_or_install(self):
        def fake_download(command, **kwargs):
            self.assertEqual(command[0], "/usr/bin/curl")
            Path(command[command.index("-o") + 1]).write_bytes(b"corrupt archive")
            return subprocess.CompletedProcess(command, 0)

        with patch.object(installer.subprocess, "check_output", return_value="15.0\n"), patch.object(installer.subprocess, "run", side_effect=fake_download) as run:
            with self.assertRaisesRegex(RuntimeError, "Checksum mismatch"):
                installer.install_zip(self.wallper, self.destination, [self.system, self.destination], None)
        self.assertEqual(run.call_count, 1)
        self.assertFalse((self.destination / self.wallper["bundle"]).exists())

    def test_verified_zip_installs_vendor_bundle_and_cleans_staging(self):
        archive = b"verified test archive"
        app = dict(self.wallper, sha256=hashlib.sha256(archive).hexdigest())
        commands = []

        def fake_command(command, **kwargs):
            commands.append(command[0])
            self.assertTrue(kwargs["check"])
            if command[0] == "/usr/bin/curl":
                Path(command[command.index("-o") + 1]).write_bytes(archive)
            elif command[0] == "/usr/bin/ditto":
                source = self.bundle(Path(command[-1]) / app["bundle"], app, "1.11.1")
                (source / "Contents/payload-link").symlink_to("payload")
            elif command[0] == "/usr/bin/codesign":
                self.assertEqual(installer.bundle_id(Path(command[-1])), app["id"])
            else:
                self.fail(f"Unexpected command: {command}")
            return subprocess.CompletedProcess(command, 0)

        with patch.object(installer.subprocess, "check_output", return_value="15.0\n"), patch.object(installer.subprocess, "run", side_effect=fake_command):
            installer.install_zip(app, self.destination, [self.system, self.destination], None)
        self.assertEqual(commands, ["/usr/bin/curl", "/usr/bin/ditto", "/usr/bin/codesign"])
        installed = self.destination / app["bundle"]
        self.assertEqual(installer.bundle_id(installed), app["id"])
        self.assertEqual((installed / "Contents/payload").read_bytes(), b"existing app must remain unchanged")
        self.assertTrue((installed / "Contents/payload-link").is_symlink())
        self.assertEqual(list(self.destination.iterdir()), [installed])

    def test_interrupted_copy_does_not_publish_partial_app(self):
        source = self.bundle(self.base / "download" / self.wallper["bundle"], self.wallper)

        def partial_copy(source, target, **kwargs):
            target = Path(target)
            target.mkdir()
            (target / "partial").write_bytes(b"incomplete")
            raise OSError("simulated interrupted copy")

        with patch.object(installer.shutil, "copytree", side_effect=partial_copy):
            with self.assertRaisesRegex(OSError, "simulated interrupted copy"):
                installer.publish_bundle(source, self.destination, self.wallper["bundle"])
        self.assertEqual(list(self.destination.iterdir()), [])
        self.assertTrue(source.is_dir())

    def test_brew_failure_propagates(self):
        result = self.run_cli([self.chrome], environment={"TEST_BREW_FAIL": "1"})
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.destination / self.chrome["bundle"]).exists())
        self.assertEqual(len(self.calls()), 1)


if __name__ == "__main__":
    unittest.main()
