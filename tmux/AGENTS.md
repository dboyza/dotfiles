# Tmux maintenance instructions

- Let Nix install and pin tmux plugins, and initialize the restoration plugins directly without TPM or tmux-yank.
  Initialize assistant restoration before continuum so restoration hooks are ready when automatic restore runs.

- Isolate tmux integration tests from the real home directory because restoration plugins install assistant hooks and write runtime state.

- Inspect complete tmux key tables and filter by table and key when checking bindings; the Brew tmux 3.7 positional key filter can return empty output even for existing bindings.
