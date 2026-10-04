// Pi 0.85.1 exposes this constructor option, but not a settings entry or setter.
// Keep the sole internal-field integration guarded and reversible.
export function createScrollStep(tui) {
  let original;
  let applied;
  return {
    apply(lines) {
      if (tui.mode !== "fullscreen") {
        original = applied = undefined;
        return true;
      }
      const current = tui.wheelScrollLines;
      if (!Number.isSafeInteger(current) || current < 1 || !Number.isSafeInteger(lines) || lines < 1) return false;
      if (original === undefined || current !== applied) original = current;
      try {
        tui.wheelScrollLines = lines;
        if (tui.wheelScrollLines !== lines) return false;
        applied = lines;
        return true;
      } catch { return false; }
    },
    dispose() {
      if (original !== undefined && tui.mode === "fullscreen" && tui.wheelScrollLines === applied) {
        try { tui.wheelScrollLines = original; } catch { /* Future readonly renderer. */ }
      }
      original = applied = undefined;
    },
  };
}
