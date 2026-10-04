# Code map and editing guide

Read the relevant section of the root [AGENTS.md](../AGENTS.md), then start with the file that owns the behavior.
Handwritten source files use a short purpose comment and `Section:` labels at responsibility boundaries.
Each explanation stays within two lines; longer rationale belongs in the component guide.
Tiny files and configuration tables use their existing structure instead of artificial sections.

## Find the owner

| Change | Entry points | Relevant checks |
| --- | --- | --- |
| Setup order, preflight, backup, activation | `bootstrap.sh`, `scripts/lib/bootstrap-{common,linux,macos}.sh` | `tests/bootstrap-latest.sh` |
| Platforms, package ownership, managed home paths | `flake.nix`, `nix/{home,homebrew,darwin}.nix` | `tests/nix-evaluation.sh`, `tests/live-config.sh`, `./bootstrap.sh --check` |
| Missing macOS desktop apps | `nix/macos-apps.json`, `scripts/install-macos-apps.py` | `tests/macos-apps.py` |
| Tool downloads, verification, updates, launch | `scripts/managed-tools.json`, `scripts/dotfiles-tool.mjs`, thin per-tool launchers | `tests/tool-{native,updates}.test.mjs` |
| Windows host installation | `scripts/install-windows-{fonts,tools,wezterm}.ps1` | `tests/windows.ps1` on PowerShell |
| Activity-only sleep protection | `scripts/adrafinil-agent-poll.py` | `tests/adrafinil-agent-poll.py`, `tests/adrafinil-agent-poll-e2e.py` |
| Terminal appearance, keys, window sizing | `wezterm/.wezterm.lua`, `wezterm/config/{appearance,keys,geometry,platform}.lua` | `tests/compatibility.sh`, `tests/check-verdicts.sh` |
| Floating tabs and native fallback | `wezterm/config/{tabs,protocol}.lua`, `wezterm/floating-tabs/{main.swift,windows.cs}` | `tests/wezterm-floating-tabs.sh`, Windows `.ps1` counterpart |
| Editor settings, mappings, plugins | `nvim/init.lua`, `nvim/lua/config/`, `nvim/lua/plugins/` | `tests/compatibility.sh`, `tests/keyboard-routing.py` |
| Clipboard selection and UTF-8 transport | `scripts/dotfiles-clipboard`, `scripts/win-{copy,paste}` | `tests/clipboard.sh`, `tests/wsl-clipboard.sh` |
| Shell, prompt, multiplexers | `zsh/`, `starship/starship.toml`, `tmux/.tmux.conf`, `herdr/*.toml` | `tests/compatibility.sh`, `tests/tmux-plugins.sh`, `tests/keyboard-routing.py` |
| Active Pi settings and archived customization | `pi/settings.json`, `pi/DEFAULTS.md`, `pi/archive/README.md` | `./tests/run.sh --archive` for archived unit checks |
| Agent instructions and authored skills | Root `AGENTS.md` for this repo; `agents/global/AGENTS.md` for shared policy; `agents/skills/` for skills | Review deployed links and the skill's own instructions |
| Test selection and pass/fail reporting | `tests/run.py`, `tests/run-lua.lua`, `scripts/lib/check-wezterm.lua` | `tests/check-runner.py`, `tests/check-verdicts.sh` |

The [terminal guide](../wezterm/README.md) documents module boundaries and the shared bridge protocol.
Use the [keyboard guide](keybindings.md) for changes that cross application layers and the [operations guide](operations.md) for activation and recovery.
Configuration edits normally take effect on application reload; changed Nix declarations or checkout paths require activation.

## Data files without comments

JSON stays valid JSON, with editing guidance here instead of invented comment fields.

| File | Fields and editing contract |
| --- | --- |
| `scripts/managed-tools.json` | Launcher-name keys with optional `github` release owner/repository; empty objects select publisher-specific discovery; adding a tool also requires its thin launcher and release logic. |
| `nix/macos-apps.json` | `bundle` and `id` identify apps; select a `cask`, `app_store_id`, or direct `url` with `sha256`; direct sources may add `minimum_macos`, `source_directory`, and `build`; preserve install-only behavior and run installer tests. |
| `tests/fixtures/floating-tabs.json` | Named snapshot/request inputs and expected validity; update consumers together and run the Lua, Swift, and native Windows checks. |
| `pi/settings.json` | Runtime preferences for theme, provider/model, thinking level, and packages; review Pi-written changes before committing and exclude credentials and sessions. |
| `pi/archive/models.json` | Archived provider endpoints, model IDs, capabilities, and limits; reactivate only on request with runtime verification. |
| `pi/archive/themes/rose-pine-moon.json` | Archived colors and UI role mappings; validate in Pi before enabling. |
| `agents/skills/readme-creation/.lavish/wezterm-inspiration/sources.json` | Provenance for reference assets used by the README skill; the neighboring HTML files are review/reference artifacts. |

## Generated and externally managed files

Preserve these outputs and edit their inputs or use their owning tool.

| Output | Owner and update path |
| --- | --- |
| `flake.lock` | Nix, from `flake.nix`; normal bootstrap updates it, while `--check` retains the pinned inputs. |
| `nvim/lazy-lock.json` | Lazy, from plugin declarations; use `:Lazy update` and review the resulting revisions. |
| `pi/archive/computer-use/requirements.txt` | uv, from adjacent `requirements.in`; regenerate with the command below, since the preserved generated header names its original pre-archive location. |
| `pi/archive/extensions/herdr-agent-state.ts` | Herdr's Pi integration installer; reinstall/update through Herdr if explicitly reactivating it, and put custom hooks beside its generated file. |
| Installed Windows loaders and launcher shims | The tracked PowerShell installers; edit those installers and regenerate the installed files. |

Preserve bundled license and attribution notices, including [Calm's license](../pi/archive/extensions/calm/LICENSE).
Its longer adapter and lifecycle notes live in [the Calm guide](../pi/archive/extensions/calm/README.md).

```sh
uv pip compile pi/archive/computer-use/requirements.in --universal --python-version 3.12 \
  --generate-hashes --output-file pi/archive/computer-use/requirements.txt
```

## Verification workflow

Run `./tests/run.sh` for active configuration, or add `--archive` for inactive Pi unit tests.
Add `--strict` when missing prerequisites should fail the run.
The runner distinguishes passed, failed, skipped, and unavailable checks; platform simulation does not establish native runtime coverage.
Run `bash tests/wezterm-floating-tabs.sh --e2e` in a macOS desktop session to measure the bridge in disposable GUI windows, including reloads.
On native Windows, run `powershell -NoProfile -File tests/windows.ps1` to exercise the Windows installers and companion path.
