#!/usr/bin/env python3
"""Exercise reporting through subprocess exit codes, without running real suites."""
from pathlib import Path
import os
import subprocess
import sys
import tempfile
import unittest

RUNNER = Path(__file__).with_name('run.py')


# Section: Isolated command outcomes
@unittest.skipIf(os.name == 'nt', 'The shell runner is for macOS/Linux/WSL; Windows uses windows.ps1')
class RunnerTests(unittest.TestCase):
    def run_checks(self, mode, *options):
        with tempfile.TemporaryDirectory() as directory:
            for name in ('bash', 'python3', 'node'):
                executable = Path(directory) / name
                executable.write_text('''#!/bin/sh
case "$1" in
  tests/bootstrap-latest.sh)
    case "$RUNNER_FIXTURE_MODE" in
      failure) exit 1 ;;
      skipped) exit 77 ;;
      unavailable) exit 78 ;;
      partial) printf 'UNAVAILABLE: fixture prerequisite\\n' ;;
    esac ;;
esac
exit 0
''')
                executable.chmod(0o755)
            return subprocess.run([sys.executable, str(RUNNER), *options], text=True, capture_output=True,
                                  env={**os.environ, 'PATH': directory, 'RUNNER_FIXTURE_MODE': mode})

    # Section: Reporting contracts
    def test_failure_is_reported_and_other_suites_still_run(self):
        result = self.run_checks('failure')
        self.assertEqual(result.returncode, 1)
        self.assertIn('FAILED      bootstrap', result.stdout)
        self.assertIn('PASSED      live configuration links', result.stdout)

    def test_skip_is_not_a_pass_or_a_strict_failure(self):
        result = self.run_checks('skipped', '--strict')
        self.assertEqual(result.returncode, 0)
        self.assertIn('SKIPPED     bootstrap', result.stdout)
        self.assertIn('SKIPPED     archived Pi extensions', result.stdout)

    def test_missing_prerequisites_are_explicit_and_strictly_enforced(self):
        for mode in ('unavailable', 'partial'):
            with self.subTest(mode=mode):
                result = self.run_checks(mode)
                self.assertEqual(result.returncode, 0)
                self.assertIn('UNAVAILABLE bootstrap', result.stdout)
                self.assertEqual(self.run_checks(mode, '--strict').returncode, 1)

    def test_archive_is_explicitly_selected(self):
        result = self.run_checks('pass', '--archive')
        self.assertEqual(result.returncode, 0)
        self.assertIn('PASSED      archived Pi extensions', result.stdout)


if __name__ == '__main__':
    unittest.main()
