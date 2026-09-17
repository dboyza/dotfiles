# Tabline.wez layout

Status: implemented, including the visual corrections and hostname-only right status requested during implementation.

## Final design

- Keep Rosé Pine colors, the existing text contrast, and 0.8 window opacity.
- Place the native WezTerm bar at the top and keep it visible with one tab.
- Use a solid `#191724` bar and matching native tab backing colors so rounded caps blend cleanly.
- Show a connected mode/workspace strip with a flat left edge, rounded transitions, and shared mode-accent text.
- Use compact numbered tabs with a subtle active surface, muted inactive labels, and a 20-cell maximum.
- Preserve explicit names; otherwise use directory names for both active and inactive tabs, with a display-cell-aware ellipsis for long names.
- Show only the rounded hostname capsule on the right.
- Omit RAM, CPU, clock, and battery, with no periodic metric subprocesses.
- Hide workspace and hostname below 100 columns, shorten hostname below 120, and compact mode below 80.

These are WezTerm tabs and workspace names, independent of Herdr and tmux.
The hostname belongs to the terminal host, including when Windows-hosted WezTerm runs a WSL pane.

## Implementation

The layout is configured in `wezterm/.wezterm.lua` through Tabline.wez.
Custom formatted status components provide matching semicircular ends and explicit backing colors.
Tabline owns status updates; older callbacks that cleared the left status have been removed.
Repository guidance records the final layout and responsive behavior.

## Validation

The real WezTerm formatting checks cover bounded Unicode titles, active and inactive naming, rounded hostname output, width thresholds, and mode changes.
Native macOS keyboard checks and simulated platform launch-size and keyboard checks pass.
Native Windows and WSL rendering have not been tested on this machine.

## References

`tabline-reference.png` contains the rounded visual reference.
`tabline-plan.html` preserves the planning preview; its system metrics were removed from the implementation at the user's request.
