import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Key } from "@earendil-works/pi-tui";
import { applyCodexPriorityTier } from "./payload.js";

const ENTRY_TYPE = "codex-fast-mode";
const STATUS_ID = "codex-fast-mode";

type FastModeState = {
	enabled: boolean;
};

export default function (pi: ExtensionAPI) {
	let enabled = false;

	function isCodexProvider(provider: string | undefined): boolean {
		return provider === "openai-codex";
	}

	function updateStatus(ctx: ExtensionContext): void {
		if (enabled && isCodexProvider(ctx.model?.provider)) {
			ctx.ui.setStatus(STATUS_ID, ctx.ui.theme.fg("warning", "⚡ fast"));
		} else {
			ctx.ui.setStatus(STATUS_ID, undefined);
		}
	}

	function toggle(ctx: ExtensionContext): void {
		if (!isCodexProvider(ctx.model?.provider)) {
			ctx.ui.notify("Codex fast mode is available only with the openai-codex provider", "warning");
			return;
		}

		enabled = !enabled;
		pi.appendEntry(ENTRY_TYPE, { enabled } satisfies FastModeState);
		updateStatus(ctx);
		ctx.ui.notify(
			enabled ? "Codex fast mode enabled for subsequent requests" : "Codex fast mode disabled",
			"info",
		);
	}

	pi.on("session_start", (_event, ctx) => {
		enabled = false;
		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type !== "custom" || entry.customType !== ENTRY_TYPE) continue;
			const state = entry.data as Partial<FastModeState> | undefined;
			if (typeof state?.enabled === "boolean") enabled = state.enabled;
		}
		updateStatus(ctx);
	});

	pi.on("model_select", (_event, ctx) => updateStatus(ctx));

	pi.on("before_provider_request", (event, ctx) => {
		if (!enabled || !isCodexProvider(ctx.model?.provider)) return;
		return applyCodexPriorityTier(event.payload);
	});

	pi.registerShortcut(Key.altShift("f"), {
		description: "Toggle Codex fast mode",
		handler: (ctx) => toggle(ctx),
	});

	pi.registerCommand("fast", {
		description: "Toggle Codex fast priority mode",
		handler: (_args, ctx) => toggle(ctx),
	});
}
