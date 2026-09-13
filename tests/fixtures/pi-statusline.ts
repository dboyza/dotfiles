// Offline TUI fixture. Load only in an isolated PI_CODING_AGENT_DIR with network denied.
import assert from "node:assert/strict";
import { type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { renderStatusline } from "../../pi/extensions/codex-statusline/render.mjs";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("footer-fixture", {
    description: "Set synthetic footer status and check real terminal-cell widths",
    handler: async (args, ctx) => {
      if (args === "structured") {
        const active = pi.getActiveTools();
        for (const name of ["exec_command", "write_stdin", "apply_patch", "view_image"]) assert.ok(active.includes(name), name);
        for (const name of ["bash", "read", "edit", "write", "exec", "notebook"]) assert.ok(!active.includes(name), name);
        await ctx.newSession({
          setup(sm) {
            const timestamp = Date.now();
            sm.appendMessage({
              role: "assistant", api: "openai-codex-responses", provider: "openai-codex", model: "gpt-6-astra",
              content: [{ type: "toolCall", id: "ui-fixture", name: "exec_command", arguments: { cmd: "printf 'UI fixture output\\n'" } }],
              stopReason: "toolUse", timestamp,
              usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } },
            });
            sm.appendMessage({
              role: "toolResult", toolCallId: "ui-fixture", toolName: "exec_command", isError: false, timestamp,
              content: [{ type: "text", text: Array.from({ length: 20 }, (_, i) => `UI fixture output ${i + 1}`).join("\n") }],
            });
          },
        });
        return;
      }
      if (args === "medium") pi.setThinkingLevel("medium");
      if (args === "other") {
        const model = ctx.modelRegistry.find("offline", "fixture-model");
        assert.ok(model);
        assert.ok(await pi.setModel(model));
        ctx.ui.setStatus("codex-adapter", undefined);
        ctx.ui.setStatus("codex-cache", undefined);
        return;
      }
      for (let width = 0; width <= 180; width++) {
        const lines = renderStatusline({
          model: "gpt-6-astra", thinking: "high", cwd: "/home/test/日本語/👩‍💻/café", home: "/home/test",
          codex: true, weekly: 61, fast: false, branch: "日本語-👩‍💻", details: ["Codex Cache • HIT • WS delta"],
        }, width, { truncateToWidth, visibleWidth });
        for (const line of lines) assert.ok(visibleWidth(line) <= width, `overflow at ${width}`);
      }
      ctx.ui.setStatus("codex-adapter", "Codex adapter V: low • notebook mode • weekly: 61% left");
      ctx.ui.setStatus("codex-cache", "Codex Cache • HIT • WS delta");
      ctx.ui.notify("Footer fixture passed: Unicode cell widths 0-180; synthetic quota/cache values.", "info");
    },
  });
}
