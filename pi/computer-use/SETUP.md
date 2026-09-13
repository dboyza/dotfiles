# Computer-use runtime setup

Pi loads the reviewed Git commit declared in `../settings.json`.
Its Python environment uses this directory's dependencies instead of upstream's vulnerable `Pillow==11.0.0` requirement.
Pillow is pinned to `12.3.0`; Playwright and PyAutoGUI retain their reviewed upstream pins.
The generated `requirements.txt` locks transitive versions and distribution hashes with platform markers.

## Safety

Pi's configured `npmCommand` disables lifecycle scripts, development dependencies, and automatic peer installation.
Keep those flags: upstream's postinstall would reinstall Pillow 11.0.0.
Do not run upstream's `requirements.txt` or `scripts/postinstall.js` manually.
Do not modify the managed Git checkout to maintain the override, because Pi can reset and clean it during package reconciliation.

Browser mode is the default and desktop control was not enabled during setup.
The first `exec_py` call requires interactive consent, but its Python process has full user permissions after approval.
A separate browser profile is not a sandbox.
Use trusted tasks and keep sensitive accounts out of the dedicated browser.

## macOS and Linux/WSL

Run from the dotfiles checkout with Pi, uv, and Python 3.12 available.
These commands use the default Pi agent directory unless `PI_CODING_AGENT_DIR` is set.

```bash
PI_CUA_SKIP_POSTINSTALL=1 npm_config_ignore_scripts=true npm_config_legacy_peer_deps=true \
  pi install git:github.com/husain-zaidi/pi-computer-use@89e3c1398650301b21086f77db1ae6839644400e

package="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/git/github.com/husain-zaidi/pi-computer-use"
uv venv --python 3.12 "$package/.venv"
uv pip sync --python "$package/.venv/bin/python" --require-hashes pi/computer-use/requirements.txt
"$package/.venv/bin/python" -m playwright install --no-shell chromium
uv pip check --python "$package/.venv/bin/python"
"$package/.venv/bin/python" -c 'from importlib.metadata import version; assert version("Pillow") == "12.3.0"; print("Pillow", version("Pillow"))'
```

A graphical session is required because the extension uses headed Chromium.
Linux desktop control additionally requires X11; native macOS desktop control requires user-granted Accessibility and Screen Recording permissions.
Linux/WSL runtime behavior was not tested during this installation.

## Native Windows PowerShell

Run from the dotfiles checkout with Pi, uv, and Python 3.12 available.

```powershell
$env:PI_CUA_SKIP_POSTINSTALL = "1"
$env:npm_config_ignore_scripts = "true"
$env:npm_config_legacy_peer_deps = "true"
pi install git:github.com/husain-zaidi/pi-computer-use@89e3c1398650301b21086f77db1ae6839644400e

$agent = if ($env:PI_CODING_AGENT_DIR) { $env:PI_CODING_AGENT_DIR } else { Join-Path $HOME ".pi/agent" }
$package = Join-Path $agent "git/github.com/husain-zaidi/pi-computer-use"
uv venv --python 3.12 "$package/.venv"
$python = Join-Path $package ".venv/Scripts/python.exe"
uv pip sync --python $python --require-hashes pi/computer-use/requirements.txt
& $python -m playwright install --no-shell chromium
uv pip check --python $python
```

Windows instructions and conditional dependencies are provided for portability but were not runtime-tested during this installation.

## Usage and updates

Run `/reload` in Pi, then `/computer-use` to check the mode and runtime status.
Use `/computer-use reset` to discard the browser and Python state.
Do not enable `/computer-use desktop` unless physical input and screen capture are needed and explicitly authorized.

Review new versions and advisories before changing `requirements.in`, then regenerate the lock from the dotfiles checkout:

```bash
uv pip compile pi/computer-use/requirements.in --universal --python-version 3.12 --generate-hashes --output-file pi/computer-use/requirements.txt
```

Do not manually edit the generated requirements file.
After changing the Git pin or recreating the managed checkout, repeat the Python setup before using `exec_py`.
Playwright's Chromium comes from its official CDN and is pinned indirectly by the Playwright version; its machine code is not covered by the source review or Python distribution hashes.
