# Tabline.wez layout plan

Status: design selected; implementation not requested.

## Selected design

- Use the existing Rosé Pine palette and 0.8 window opacity.
- Place the native WezTerm tab bar at the top and keep it visible with one tab.
- Use rounded half-circle separators and compact rounded active tabs.
- Use fully rounded, separate battery and hostname capsules with a one-cell gap.
- Show lowercase mode and WezTerm workspace at the left.
- Show compact numbered native tabs in the middle.
- Show RAM, CPU, time, battery when available, and hostname at the right.
- Preserve explicit tab names; otherwise use directory names for active tabs and process names for inactive tabs.

These describe WezTerm state, not Herdr or tmux tabs and workspaces.
Metrics describe the terminal host, including when a Windows-hosted WezTerm pane runs WSL.

## Implementation

1. Update the Tabline setup in `wezterm/.wezterm.lua` to use the selected sections and rounded glyphs.
   Retain display-cell-aware truncation and the 24-cell maximum, while removing fixed-width centered labels.
2. Set the bar to the top and disable single-tab hiding.
   Remove the resize and reload handlers that clear the left status, so they cannot erase mode and workspace information.
3. Render battery and hostname with explicit rounded formatting if stock section separators cannot produce both capsule ends cleanly.
   Keep the terminal palette, text contrast, and opacity unchanged.
4. Reserve space for tabs first.
   Start by hiding RAM/CPU below 140 columns, shortening hostname below 120, and hiding hostname and workspace below 100.
   Below 80 columns, show tabs and a compact mode indicator.
   Adjust these thresholds if real terminal checks reveal crowding.
5. Use platform-specific metric implementations with a five-second throttle.
   Enable the Windows PowerShell/CIM path instead of WMIC.
   Omit unavailable measurements and battery information on machines without a battery.
   Verify that collection does not visibly delay terminal interaction.
6. Update repository instructions that currently require bottom placement, single-tab hiding, and empty left sections.
   Update the existing tab integration checks and run keyboard and launch-size checks.
   Commit locally after implementation and validation.

## Validation

- Check rendered format items using the real WezTerm API and inspect the terminal presentation.
- Cover one and many tabs, narrow and wide windows, long Unicode titles, explicit names, active and inactive tabs, hover, and mode changes.
- Verify that status updates and reloads preserve left sections without flicker or stale padding.
- Verify rounded boundaries and one-cell gaps with the installed Nerd Font.
- Exercise missing metric and battery cases.
- Run native macOS checks and simulated platform tests for Windows/Linux; report any untested native paths explicitly.

## Reference

The selected reference is `tabline-reference.png`.
The finalized visual plan is `tabline-plan.html`.
The preview uses the project's existing Rosé Pine colors rather than the reference's teal palette.
