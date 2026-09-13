import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => ctx.ui.setStatus("scroll-test", "Scroll fixture ready"));
  pi.registerEntryRenderer("scroll-fixture", () => new Text(
    Array.from({ length: 300 }, (_, i) => `SCROLL_ROW_${String(i + 1).padStart(3, "0")}`).join("\n"), 0, 0,
  ));
  pi.registerCommand("scroll-fixture", {
    description: "Display numbered rows without a model request",
    handler: async () => { pi.appendEntry("scroll-fixture", {}); },
  });
}
