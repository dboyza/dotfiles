# Pi package security review

Reviewed on 2026-09-13 against the published npm artifacts, before enabling the packages.
No malicious behavior was identified in the inspected source, compiled JavaScript, prompts, or dependency entry points.
This is a bounded static review, not proof that every binary or future release is safe.

## Reviewed pins

| Package | Version | Claimed upstream commit |
| --- | --- | --- |
| `@howaboua/pi-codex-conversion` | `3.0.34` | `a88a72bc68d133b6648da133ea9056cda70cf0c5` |
| `@howaboua/pi-codex-imagegen` | `0.0.4` | `8995b342efd7a14a1e90476a2246618a19d212b4` |
| `@howaboua/pi-ask` | `0.0.9` | `1892cc8f36303a0fd92a3d267fd6658e07fdf418` |
| `@howaboua/pi-shepherdr` | `0.2.3` | `a88a72bc68d133b6648da133ea9056cda70cf0c5` |
| `@howaboua/pi-auto-trees` | `0.1.15` | `8995b342efd7a14a1e90476a2246618a19d212b4` |

Upstream repository: <https://github.com/IgorWarzocha/howaboua-pi-stuff>.
The pins in `settings.json` are the authoritative installation configuration.

## Verification performed

- Downloaded the npm tarballs with lifecycle scripts disabled and verified their SHA-512 registry integrity values.
- Compared all published files that exist in the claimed upstream commits against their Git blob hashes.
  All 116 files across Imagegen, Ask, Shepherdr, and Auto Trees matched.
  Conversion had 454 matching tracked files and 643 generated JavaScript/declaration files absent from Git, with no differing tracked files.
- Reviewed Conversion's published JavaScript as well as its TypeScript, native-helper metadata, execution paths, provider integration, and voice/network features.
- Reviewed the other four packages' source and prompt files, including startup behavior, credential access, network destinations, persistence, and subprocess paths.
- Inspected runtime dependencies separately, with no unexpected credential harvesting, covert telemetry, or malicious lifecycle payload identified.
  Dependency review was bounded rather than a line-by-line audit of every transitive library.
- Installed exact npm versions with `npm_config_ignore_scripts=true` and `npm_config_save_exact=true`.
- Compared every installed package artifact file against the reviewed tarball contents.
  All 1,213 files matched, and 31 installed dependency integrity entries matched the separately reviewed dependency versions.
- Ran npm's vulnerability and signature checks on the complete managed installation, including the pre-existing web-access package.
  There were zero reported advisories, 150 verified registry signatures, and 22 verified attestations.
  Registry signatures establish artifact provenance, not benign behavior.

## Important risks and behavior

### Codex Conversion

- **Do not enable its unauthenticated LAN voice/control server on a shared or untrusted network.**
  `src/voice/lan/server-runtime.ts` binds to `0.0.0.0`, and `src/voice/lan/http-handler.ts` permits client-controlled operations without authentication.
  A reachable attacker could observe activity or submit prompts through `/api/send`.
  The server is off by default and was not enabled during installation or validation.
- The structured adapter replaces Pi's normal file and shell tools with `exec_command`, `write_stdin`, `apply_patch`, and `view_image` for compatible models.
  These retain full user privileges; they are not a sandbox.
- The artifact includes 24 platform-specific native executables.
  They matched tracked upstream artifacts, but their machine-code behavior was not independently verified or reproduced from source.
  This limits the assurance of the review.
- Code Mode and Notebook Mode can download additional pinned, hash-checked executables.
  These modes remain opt-in and were not enabled or exercised.
  Hash verification does not establish that a maintainer-provided executable is benign.
- Voice and dictation send audio to OpenAI when explicitly used.
  Remote history/notes and image-description fallback also transmit their corresponding content when enabled.
- Default usage refresh and WebSocket prewarming can contact the configured Codex provider at startup.
  Prewarming may send system-prompt/tool context before the first user turn.
  Pi's core offline flag should not be assumed to disable third-party extension networking.

### Imagegen

- Uses Pi's configured Codex authentication to send prompts and selected images to the resolved provider.
- Accepts readable image paths outside the workspace and can reuse conversation images.
  Review requested inputs before uploading sensitive images.
- Saves results beneath `.pi/openai-codex-images` and overwrites `latest.png` intentionally.
  Existing workspace symlinks can redirect ordinary filesystem writes.

### Ask

- Presents model-authored questions and returns answers to the conversation, with pending state persisted in the session.
  Treat approval text as untrusted model output, not as an independent security decision.
- Optional prompt templates can direct repository exploration, document creation, and editor use when invoked.

### Shepherdr

- Controls local and configured remote Herdr agents and reads their terminal output and Pi transcripts.
  Those results may be sent to the controlling model.
- Inside Herdr, connects enabled machine profiles using existing noninteractive SSH access.
  Only use trusted profiles and hosts.
- Writes bridge source files under the remote Pi agent directory and leaves those files in place after disconnecting, but does not install a persistent remote daemon.
- Editable profiles and preparation modules are executable configuration and must remain trusted.
  Bundled worker profiles have their own model/effort defaults rather than inheriting the controller's settings.

### Auto Trees

- `/end` can submit conversation history to the configured summary provider.
  The default preferred summary model is OpenAI Codex Luna, with fallback behavior when unavailable.
- Creates local configuration and persists marker/tree state in Pi sessions.

## Validation and limits

All five extensions loaded together in Pi 0.85.1 on macOS ARM64 with Node.js 24.19.0.
RPC state, command discovery, and registered/active tool inspection passed with network access denied by an OS sandbox and Herdr context variables removed.
The expected Imagegen, Ask, Agents, Codex adapter tools, `/codex`, `/herdr`, `/marker`, `/prime`, and `/end` surfaces were present, without extension errors.
The existing dotfiles cross-platform configuration compatibility checks also passed.

No image generation, audio capture, remote SSH connection, worker dispatch, native-helper execution, or Code/Notebook download was performed as part of validation.
Windows and Linux package runtime behavior was not executed or validated.
Future package versions and new dependency resolutions require another review.
