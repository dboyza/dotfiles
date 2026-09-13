import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { createScrollStep } from "./step.mjs";

export default function (pi: ExtensionAPI) {
  let lines = 5;
  let apply: (() => void) | undefined;
  let restore: (() => void) | undefined;
  const dispose = () => { restore?.(); restore = apply = undefined; };

  pi.on("session_start", (_event, ctx) => {
    dispose();
    if (ctx.mode !== "tui") return;
    // The public widget factory gives us the live renderer reference without
    // replacing the editor/footer. The scalar adjustment is isolated in step.mjs.
    ctx.ui.setWidget("scroll-sensitivity", (tui) => {
      dispose();
      const step = createScrollStep(tui);
      let warned = false;
      restore = () => step.dispose();
      apply = () => {
        if (!step.apply(lines) && !warned) {
          warned = true;
          ctx.ui.notify("Scroll sensitivity is incompatible with this Pi renderer; keeping its defaults.", "warning");
        }
      };
      apply();
      return { render: () => { apply?.(); return []; }, invalidate() {}, dispose };
    });
  });
  pi.on("session_shutdown", dispose);
  pi.registerCommand("scroll-speed", {
    description: "Set fullscreen wheel scrolling to fast (5x) or normal for this session",
    handler: async (args, ctx) => {
      const value = args.trim();
      if (value !== "fast" && value !== "normal") {
        ctx.ui.notify("Usage: /scroll-speed fast | normal", "info");
        return;
      }
      lines = value === "fast" ? 5 : 1;
      apply?.();
      ctx.ui.notify(`Scrolling: ${value}`, "info");
    },
  });
}
