# Pi factory-default profile

`settings.json` is an empty object so Pi uses its own defaults rather than a copied list that can drift with updates.
On Pi 0.85.1 this means the built-in dark theme, regular terminal mode, standard tools and footer, visible thinking, and the default project-trust prompt.
No default model or reasoning override is pinned by dotfiles.
Pi may later write ordinary runtime preferences and version metadata into the managed settings file.

Home Manager deploys only Pi's settings and shared agent instructions.
The source under `extensions/`, `themes/`, `models.json`, and the package review/setup documents is retained as an inactive archive, not loaded automatically.
Do not restore those deployment links or package entries without an explicit request.
The shared skills directory remains available through Pi's normal discovery, unchanged for other agents.

## Local reset and recovery

The reset backs up configuration beneath `~/.pi/backups/factory-reset-*` with an owner-only parent directory.
It disconnects the active extension/theme/model links and moves extension preference files out of the agent directory.
Credentials, conversation history, shared instructions, downloaded package caches, and model catalogs are preserved.
An unreferenced npm or Git package cache is not an enabled extension.

Completely exit Pi and launch it again after a reset instead of resuming the old session or only reloading extensions.
The running process retains its old configuration and tools until restarted, and resuming a conversation can restore its old model selection.
Changes to other applications or their integrations are not part of this reset.

If customization is requested again, restore only the approved settings and resources from the backup.
Before installing packages, reapply disabled npm lifecycle scripts and review exact package pins as described in `PACKAGE-REVIEW.md`.
