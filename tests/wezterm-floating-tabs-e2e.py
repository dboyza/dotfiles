#!/usr/bin/env python3
"""Measure the real macOS GUI bridge using disposable idle windows, without AX.

Run through tests/wezterm-floating-tabs.sh --e2e in a desktop session.
Requests use the companion's atomic file protocol; no terminal input is sent.
"""

import argparse
import json
import math
import os
from pathlib import Path
import shutil
import statistics
import subprocess
import sys
import tempfile
import time


REPO = Path(__file__).resolve().parents[1]


def wait_for(predicate, description, timeout=10):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = predicate()
        if result:
            return result
        time.sleep(0.002)
    raise AssertionError(f"Timed out waiting for {description}")


def read_snapshot(path):
    try:
        return json.loads(path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def measure(bridge, snapshots):
    samples = []
    for index in range(24):
        # Cover different timer phases and both the foreground/background window.
        time.sleep((index * 0.037) % 0.19)
        path = snapshots[index % len(snapshots)]
        snapshot = read_snapshot(path)
        other = snapshots[(index + 1) % len(snapshots)]
        other_active = next(tab["id"] for tab in read_snapshot(other)["tabs"] if tab["active"])
        target = next(tab["id"] for tab in snapshot["tabs"] if not tab["active"])
        temporary = bridge / "request.tmp"
        temporary.write_text(json.dumps({
            "title": snapshot["title"], "updated": time.time(), "tab_id": target,
        }))
        request = bridge / f"activate-{snapshot['key']}.json"
        started = time.monotonic()
        temporary.replace(request)

        def selected():
            current = read_snapshot(path)
            return current and any(tab["id"] == target and tab["active"] for tab in current["tabs"])

        wait_for(selected, "requested tab activation", timeout=3)
        samples.append((time.monotonic() - started) * 1000)
        assert not request.exists(), "The click must be consumed before activation"
        assert any(tab["id"] == other_active and tab["active"] for tab in read_snapshot(other)["tabs"]), \
            "A click must not switch another window's tab"
    return {
        "median_ms": round(statistics.median(samples), 1),
        "p95_ms": round(sorted(samples)[math.ceil(len(samples) * 0.95) - 1], 1),
        "max_ms": round(max(samples), 1),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wezterm", required=True, help="Foreground wezterm-gui executable")
    parser.add_argument("--config", type=Path, default=REPO / "wezterm/.wezterm.lua")
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("This GUI timing check requires macOS; use the PowerShell bridge checks on Windows")

    with tempfile.TemporaryDirectory(prefix="floating-tabs-e2e-") as directory:
        fixture = Path(directory)
        bridge = fixture / ".local/state/dotfiles/wezterm-floating-tabs"
        bridge.mkdir(parents=True)
        helper = fixture / "Applications/WezTerm Floating Tabs.app/Contents/MacOS/wezterm-floating-tabs"
        helper.parent.mkdir(parents=True)
        helper.touch()
        # Copy the configuration so reload checks never edit the live checkout.
        checkout = fixture / "checkout with spaces"
        shutil.copytree(args.config.resolve().parent, checkout)
        source_path = checkout / args.config.name
        config = fixture / "test.lua"
        config.write_text("""local w = require 'wezterm'
w.home_dir = """ + json.dumps(str(fixture)) + """
w.background_child_process = function() end
local on = w.on
w.on = function(name, callback)
  if name ~= 'gui-startup' then
    on(name, function(...)
      local ok, result = pcall(callback, ...)
      if not ok then
        local errors = assert(io.open(w.home_dir .. '/lua-errors', 'a'))
        errors:write(name .. ': ' .. tostring(result) .. '\\n')
        errors:close()
      end
      return ok and result or nil
    end)
  end
end
local source = """ + json.dumps(str(source_path)) + """
local config = assert(loadfile(source))(source)
w.on = on
w.on('gui-startup', function()
  for _ = 1, 2 do
    local _, _, window = w.mux.spawn_window { args = { '/bin/sleep', '90' } }
    window:spawn_tab { args = { '/bin/sleep', '90' } }
  end
end)
config.initial_cols = 60
config.initial_rows = 15
config.check_for_updates = false
local loaded = assert(io.open(w.home_dir .. '/loaded', 'a'))
loaded:write('loaded\\n')
loaded:close()
return config
""")
        environment = {key: value for key, value in os.environ.items() if not key.startswith("WEZTERM_")}
        environment["XDG_RUNTIME_DIR"] = str(fixture / "runtime")
        environment["XDG_DATA_HOME"] = str(fixture / "data")
        with (fixture / "gui.log").open("w+") as log:
            process = subprocess.Popen([
                args.wezterm, "--config-file", str(config), "start", "--always-new-process",
                "--class", f"floating-tabs-test-{os.getpid()}",
            ], stdout=log, stderr=log, env=environment)
            try:
                def ready():
                    paths = sorted(bridge.glob("window-*.json"))
                    return paths if len(paths) == 2 and all(
                        len((read_snapshot(path) or {}).get("tabs", [])) == 2 for path in paths
                    ) else None

                snapshots = wait_for(ready, "two isolated windows with two idle tabs", timeout=20)
                # Exclude window creation, font loading and initial config overrides.
                time.sleep(1)
                results = {"idle_windows": measure(bridge, snapshots)}
                loaded = (fixture / "loaded").read_text()
                with config.open("a") as source:
                    source.write("\n-- Exercise automatic configuration reload.\n")
                wait_for(lambda: (fixture / "loaded").read_text() != loaded, "configuration reload")
                time.sleep(1)
                results["after_reload"] = measure(bridge, snapshots)
                loaded = (fixture / "loaded").read_text()
                with (checkout / "config/tabs.lua").open("a") as module:
                    module.write("\n-- Exercise a watched module reload.\n")
                wait_for(lambda: (fixture / "loaded").read_text() != loaded, "module reload")
                time.sleep(1)
                results["after_module_reload"] = measure(bridge, snapshots)
                errors = fixture / "lua-errors"
                assert not errors.exists(), errors.read_text() if errors.exists() else ""
                print(json.dumps(results, indent=2), flush=True)
                for result in results.values():
                    # Background-window scheduling is slower than the 16 ms input
                    # cadence. Leave desktop-load headroom while rejecting the
                    # original timer's roughly 130 ms median / 250 ms tail.
                    assert result["median_ms"] < 80 and result["p95_ms"] < 200, \
                        "Click latency regressed toward the 250 ms status timer"
            except BaseException:
                log.seek(0)
                print(log.read(), file=sys.stderr)
                errors = fixture / "lua-errors"
                if errors.exists():
                    print(errors.read_text(), file=sys.stderr)
                raise
            finally:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


if __name__ == "__main__":
    main()
