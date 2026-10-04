// Pi Calm - an archived toggle for conversation presentation.
// Change rendering only; execution, stored messages, and exports remain complete.

// Adapted from the Firstmate project's Calm implementation.
// Copyright (c) 2026 Kun Chen. MIT License - see the LICENSE file in this directory.

import { type ExtensionAPI, type ExtensionUIContext } from "@earendil-works/pi-coding-agent";
import { getKeybindings } from "@earendil-works/pi-tui";
import { installCalmBuiltInToolShellLayout } from "./lib/built-in-tool-shells.ts";
import { installCalmCollapsedThinkingLayout } from "./lib/collapsed-thinking.ts";
import { loadCalmPreference, persistCalmPreference } from "./lib/preference.ts";
import {
  calmPresentationIsActive,
  setCalmPresentation,
  setCalmStockExportRendering,
} from "./lib/visibility.ts";
import {
  CALM_WORKING_SHIP_WIDGET_KEY,
  createCalmWorkingShipAnimation,
  createCalmWorkingShipWidget,
} from "./lib/working-ship.ts";

// Section: Guarded presentation adapters

// Skip only the adapter whose Pi API is unavailable; other presentation features still work.
function installCalmPresentationAdapter(name: string, install: () => void): void {
  try {
    install();
  } catch (error) {
    const reason = error instanceof Error ? error.message : String(error);
    console.error(`Pi Calm: ${name} presentation adapter unavailable, skipping. ${reason}`);
  }
}

// Section: User toggle and session lifecycle
export default function (pi: ExtensionAPI) {
  installCalmPresentationAdapter("collapsed-thinking", installCalmCollapsedThinkingLayout);
  installCalmPresentationAdapter("built-in-tool-shells", installCalmBuiltInToolShellLayout);

  let removeTerminalInputHandler: (() => void) | undefined;
  // Track the full agent run so tool calls, retries, and compaction do not flicker the boat.
  let agentRunActive = false;
  let workingShipShown = false;
  // Reuse frozen animation state within this extension lifetime; session_start resets it.
  const workingShipAnimation = createCalmWorkingShipAnimation();

  // Create or remove the widget only on transitions, keeping exactly one animation timer.
  const applyWorkingPresentation = (
    ui: ExtensionUIContext,
    forceStockVisibility = false,
  ): void => {
    const showShip = agentRunActive && calmPresentationIsActive();
    if (showShip !== workingShipShown) {
      workingShipShown = showShip;
      ui.setWidget(
        CALM_WORKING_SHIP_WIDGET_KEY,
        showShip
          ? (tui) => createCalmWorkingShipWidget(tui, workingShipAnimation)
          : undefined,
      );
      ui.setWorkingVisible(!showShip);
    } else if (forceStockVisibility && !showShip) {
      ui.setWorkingVisible(true);
    }
  };

  pi.on("session_start", (_event, ctx) => {
    setCalmPresentation(loadCalmPreference());
    setCalmStockExportRendering(false);
    agentRunActive = false;
    workingShipShown = false;
    // A genuine new session lifetime starts the boat at the normal initial position.
    workingShipAnimation.reset();
    applyWorkingPresentation(ctx.ui, true);
    ctx.ui.setHiddenThinkingLabel(calmPresentationIsActive() ? "" : undefined);
    removeTerminalInputHandler?.();
    removeTerminalInputHandler = ctx.ui.onTerminalInput((data) => {
      if (!getKeybindings().matches(data, "tui.input.submit")) return;

      const input = ctx.ui.getEditorText().trim();
      if (
        input !== "/share" &&
        input !== "/export" &&
        !input.startsWith("/export ")
      ) {
        return;
      }

      // Export/share reuse transcript renderers, so temporarily restore stock presentation.
      // Stored messages and export data remain unfiltered.
      setCalmStockExportRendering(true);
      setTimeout(() => {
        setCalmStockExportRendering(false);
        const expanded = ctx.ui.getToolsExpanded();
        ctx.ui.setToolsExpanded(!expanded);
        ctx.ui.setToolsExpanded(expanded);
      }, 0);
    });
  });

  pi.on("agent_start", (_event, ctx) => {
    agentRunActive = true;
    applyWorkingPresentation(ctx.ui);
  });

  // agent_settled is emitted from a finally block, so it also covers abort and failure.
  pi.on("agent_settled", (_event, ctx) => {
    agentRunActive = false;
    applyWorkingPresentation(ctx.ui);
  });

  pi.on("session_shutdown", (_event, ctx) => {
    agentRunActive = false;
    applyWorkingPresentation(ctx.ui);
  });

  pi.registerCommand("calm", {
    description: "Toggle Calm: hide collapsed thinking and built-in tool shells from the transcript (presentation only).",
    handler: async (_args, ctx) => {
      const active = !calmPresentationIsActive();
      // Persist first: if the state file cannot be written, the toggle fails
      // with a clear error instead of silently reverting on the next restart.
      persistCalmPreference(active);
      setCalmPresentation(active);
      applyWorkingPresentation(ctx.ui, true);
      ctx.ui.setHiddenThinkingLabel(active ? "" : undefined);

      // Flip expansion twice to force a transcript redraw while preserving the
      // user's exact Ctrl+O tools-expanded state.
      const expanded = ctx.ui.getToolsExpanded();
      ctx.ui.setToolsExpanded(!expanded);
      ctx.ui.setToolsExpanded(expanded);
    },
  });
}
