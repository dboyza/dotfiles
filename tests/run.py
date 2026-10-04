#!/usr/bin/env python3
"""Local verification. 77 means not applicable, 78 means a prerequisite is absent."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys

REPO = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', action='store_true', help='Include inactive Pi extension checks')
    parser.add_argument('--strict', action='store_true', help='Fail if any prerequisite is unavailable')
    args = parser.parse_args()
    # Section: Suite selection
    suites = [
        ('macOS app installer', ['python3', '-B', 'tests/macos-apps.py']),
        ('activity decisions', ['python3', '-B', 'tests/adrafinil-agent-poll.py']),
        ('activity CLI workflow', ['python3', '-B', 'tests/adrafinil-agent-poll-e2e.py']),
        ('managed tools', ['node', '--test', 'tests/tool-updates.test.mjs', 'tests/tool-native.test.mjs']),
        ('Herdr workspace', ['node', '--test', 'tests/herdr-workspace.test.mjs']),
        ('runner reporting', ['python3', '-B', 'tests/check-runner.py']),
        ('check verdicts', ['bash', 'tests/check-verdicts.sh']),
        ('bootstrap', ['bash', 'tests/bootstrap-latest.sh']),
        ('WSL clipboard', ['bash', 'tests/wsl-clipboard.sh']),
        ('clipboard routing', ['bash', 'tests/clipboard.sh']),
        ('tmux plugins', ['bash', 'tests/tmux-plugins.sh']),
        ('keyboard PTY routing', ['python3', '-B', 'tests/keyboard-routing.py']),
        ('configuration compatibility', ['bash', 'tests/compatibility.sh']),
        ('floating tabs', ['bash', 'tests/wezterm-floating-tabs.sh']),
        ('Nix platform evaluation', ['bash', 'tests/nix-evaluation.sh']),
        ('live configuration links', ['bash', 'tests/live-config.sh']),
    ]
    results = []
    if args.archive:
        suites.append(('archived Pi extensions', ['node', '--test', 'tests/pi-statusline.test.mjs', 'tests/pi-scroll.test.mjs']))
    else:
        results.append(('archived Pi extensions (opt in with --archive)', 'SKIPPED'))
    # Section: Execution and explicit coverage outcomes
    for name, command in suites:
        print(f'\nRunning {name}', flush=True)
        if not shutil.which(command[0]):
            status = 'UNAVAILABLE'
            print(f'Missing {command[0]}')
        else:
            result = subprocess.run(command, cwd=REPO, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            print(result.stdout, end='', flush=True)
            status = {0: 'PASSED', 77: 'SKIPPED', 78: 'UNAVAILABLE'}.get(result.returncode, 'FAILED')
            if status == 'PASSED' and any(line.startswith('UNAVAILABLE:') for line in result.stdout.splitlines()):
                status = 'UNAVAILABLE'
        results.append((name, status))
    # Section: Summary and process verdict
    print('\nLocal verification results')
    for name, status in results:
        print(f'{status:11} {name}')
    print('\nPlatform simulation and Nix evaluation do not establish native Windows or Linux runtime coverage.')
    failures = any(status == 'FAILED' or (args.strict and status == 'UNAVAILABLE') for _, status in results)
    return int(failures)


if __name__ == '__main__':
    sys.exit(main())
