import {
	VERSION,
	type ExtensionAPI,
	type ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";
import { OpenAIStatusPanel } from "./panel.js";
import {
	extractOpenAIIdentity,
	formatOpenAIUsage,
	parseOpenAIUsageStatus,
} from "./usage.js";

const USAGE_URL = "https://chatgpt.com/backend-api/wham/usage";

function findHeader(headers: Record<string, string> | undefined, name: string): string | undefined {
	const match = Object.entries(headers ?? {}).find(([key]) => key.toLowerCase() === name.toLowerCase());
	return match?.[1];
}

function displayPath(path: string): string {
	const home = process.env.HOME ?? process.env.USERPROFILE;
	if (!home) return path;
	const candidate = process.platform === "win32" ? path.toLowerCase() : path;
	const normalizedHome = process.platform === "win32" ? home.toLowerCase() : home;
	const boundary = path[home.length];
	return candidate.startsWith(normalizedHome) &&
		(candidate.length === normalizedHome.length || boundary === "/" || boundary === "\\")
		? `~${path.slice(home.length)}`
		: path;
}

function sessionFastModeEnabled(ctx: ExtensionCommandContext): boolean {
	let enabled = false;
	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type !== "custom" || entry.customType !== "codex-fast-mode") continue;
		const value = entry.data as { enabled?: unknown } | undefined;
		if (typeof value?.enabled === "boolean") enabled = value.enabled;
	}
	return enabled;
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("status", {
		description: "Show OpenAI Codex account and current context usage",
		handler: async (_args, ctx) => {
			const model =
				ctx.model?.provider === "openai-codex"
					? ctx.model
					: ctx.modelRegistry.getAvailable().find((candidate) => candidate.provider === "openai-codex");
			if (!model) {
				ctx.ui.notify("OpenAI Codex is not configured", "warning");
				return;
			}

			try {
				const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
				if (!auth.ok) throw new Error(auth.error);
				if (!auth.apiKey) throw new Error("OpenAI Codex OAuth access token is unavailable");

				const identity = extractOpenAIIdentity(auth.apiKey);
				const accountId =
					findHeader(auth.headers, "chatgpt-account-id") ?? identity.accountId;
				if (!accountId) throw new Error("OpenAI Codex account ID is unavailable");

				const headers = new Headers(auth.headers);
				headers.set("authorization", `Bearer ${auth.apiKey}`);
				headers.set("chatgpt-account-id", accountId);
				headers.set("originator", "pi");
				headers.set("accept", "application/json");

				const response = await fetch(USAGE_URL, {
					headers,
					signal: AbortSignal.timeout(15_000),
				});
				if (!response.ok) throw new Error(`OpenAI usage request failed with HTTP ${response.status}`);

				const payload: unknown = await response.json();
				const contextUsage = ctx.getContextUsage();
				const contextText =
					contextUsage && contextUsage.tokens !== null && contextUsage.percent !== null
						? `${contextUsage.tokens.toLocaleString()} / ${contextUsage.contextWindow.toLocaleString()} tokens (${contextUsage.percent.toFixed(1)}%)`
						: undefined;
				if (ctx.mode !== "tui") {
					const lines = formatOpenAIUsage(payload);
					if (contextText) lines.push(`Current context: ${contextText}`);
					ctx.ui.notify(lines.join("\n"), "info");
					return;
				}

				const contextFiles = ctx.getSystemPromptOptions().contextFiles ?? [];
				const agents = contextFiles.length > 0
					? contextFiles.map(({ path }) => displayPath(path)).join(", ")
					: "none";
				await ctx.ui.custom<void>(
					(_tui, theme, _keybindings, done) =>
						new OpenAIStatusPanel(
							theme,
							{
								version: VERSION,
								model: model.id,
								reasoning: pi.getThinkingLevel(),
								directory: displayPath(ctx.cwd),
								permissions: "Full workspace access",
								agents,
								account: identity.email ?? "OpenAI account",
								collaborationMode: "Default",
								session: ctx.sessionManager.getSessionId(),
								fastMode: sessionFastModeEnabled(ctx),
								context: contextText,
								usage: parseOpenAIUsageStatus(payload),
							},
							() => done(undefined),
						),
					{
						overlay: true,
						overlayOptions: {
							width: "94%",
							minWidth: 54,
							maxHeight: "90%",
							anchor: "center",
							margin: 1,
						},
					},
				);
			} catch (error) {
				const message = error instanceof Error ? error.message : String(error);
				ctx.ui.notify(`Unable to load OpenAI usage: ${message}`, "error");
			}
		},
	});
}
