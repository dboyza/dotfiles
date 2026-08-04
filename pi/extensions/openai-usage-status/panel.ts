import type { Theme } from "@earendil-works/pi-coding-agent";
import {
	hyperlink,
	matchesKey,
	truncateToWidth,
	type Component,
	visibleWidth,
} from "@earendil-works/pi-tui";
import type { OpenAIUsageStatus, UsageWindowStatus } from "./usage.js";

export type StatusPanelData = {
	version: string;
	model: string;
	reasoning: string;
	directory: string;
	permissions: string;
	agents: string;
	account: string;
	collaborationMode: string;
	session: string;
	fastMode: boolean;
	context?: string;
	usage: OpenAIUsageStatus;
};

const USAGE_URL = "https://chatgpt.com/codex/settings/usage";

function formatPlan(plan: string): string {
	return plan
		.replace(/lite$/i, " Lite")
		.split(/[_-]/)
		.map((part) => part.charAt(0).toUpperCase() + part.slice(1))
		.join(" ");
}

function formatReset(resetAt: number | undefined): string {
	if (resetAt === undefined) return "";
	const date = new Date(resetAt * 1000);
	const time = date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", hour12: false });
	const day = date.toLocaleDateString([], { day: "2-digit" });
	const month = date.toLocaleDateString([], { month: "short" });
	return ` (resets ${time} on ${day} ${month})`;
}

export class OpenAIStatusPanel implements Component {
	constructor(
		private readonly theme: Theme,
		private readonly data: StatusPanelData,
		private readonly close: () => void,
	) {}

	handleInput(input: string): void {
		if (matchesKey(input, "escape") || matchesKey(input, "enter") || matchesKey(input, "ctrl+c")) {
			this.close();
		}
	}

	invalidate(): void {}

	render(width: number): string[] {
		const innerWidth = Math.max(1, width - 2);
		const border = (text: string) => this.theme.fg("borderMuted", text);
		const line = (content = "") => {
			const clipped = truncateToWidth(content, innerWidth, "");
			return `${border("│")}${clipped}${" ".repeat(Math.max(0, innerWidth - visibleWidth(clipped)))}${border("│")}`;
		};
		const contentWidth = Math.max(1, innerWidth - 4);
		const content = (value = "") => line(`  ${value}`);
		const rows: string[] = [border(`╭${"─".repeat(innerWidth)}╮`)];

		rows.push(
			content(
				`${this.theme.fg("muted", ">_")} ${this.theme.bold("OpenAI Codex")} ${this.theme.fg("dim", `(Pi v${this.data.version})`)}`,
			),
		);
		rows.push(content());
		rows.push(
			content(
				this.theme.fg("error", "Visit ") +
					hyperlink(this.theme.fg("error", USAGE_URL), USAGE_URL) +
					this.theme.fg("error", " for up-to-date information on rate limits and credits"),
			),
		);
		rows.push(content());

		const details: Array<[string, string]> = [
			["Model:", `${this.data.model} (reasoning ${this.data.reasoning}${this.data.fastMode ? ", fast" : ""})`],
			["Directory:", this.data.directory],
			["Permissions:", this.data.permissions],
			["Agents.md:", this.data.agents],
			["Account:", `${this.data.account} (${formatPlan(this.data.usage.plan)})`],
			["Collaboration mode:", this.data.collaborationMode],
			["Session:", this.data.session],
		];
		if (this.data.context) details.push(["Context:", this.data.context]);
		if (this.data.usage.credits !== undefined) details.push(["Credits:", this.data.usage.credits]);

		const labelWidth = Math.min(22, Math.max(...details.map(([label]) => label.length)) + 2);
		for (const [label, value] of details) {
			rows.push(
				content(
					`${this.theme.fg("muted", label.padEnd(labelWidth))}${this.theme.fg("text", value)}`,
				),
			);
		}
		rows.push(content());

		const limits: Array<{ label: string; window: UsageWindowStatus }> = this.data.usage.windows.map((window) => ({
			label: `${window.label} limit:`,
			window,
		}));
		for (const limit of this.data.usage.additionalLimits) {
			for (const window of limit.windows) {
				limits.push({ label: `${limit.name} ${window.label} limit:`, window });
			}
		}
		const desiredLimitLabelWidth = Math.max(14, ...limits.map(({ label }) => label.length + 1));
		const limitLabelWidth = Math.max(14, Math.min(38, contentWidth - 20, desiredLimitLabelWidth));
		for (const { label, window } of limits) {
			const percentText = `${Math.round(window.remainingPercent)}% left`;
			const resetText = formatReset(window.resetAt);
			const wideSuffix = `${percentText}${resetText}`;
			const fitsOneLine = contentWidth - limitLabelWidth - visibleWidth(wideSuffix) - 3 >= 8;
			const suffix = fitsOneLine ? wideSuffix : percentText;
			const barWidth = Math.max(8, Math.min(20, contentWidth - limitLabelWidth - visibleWidth(suffix) - 3));
			const filled = Math.max(0, Math.min(barWidth, Math.round((window.remainingPercent / 100) * barWidth)));
			const bar =
				`[${this.theme.fg("accent", "█".repeat(filled))}` +
				`${this.theme.fg("dim", "░".repeat(barWidth - filled))}]`;
			rows.push(
				content(
					`${this.theme.fg("muted", label.padEnd(limitLabelWidth))}${bar} ${this.theme.fg("text", suffix)}`,
				),
			);
			if (!fitsOneLine && resetText) {
				rows.push(content(`${" ".repeat(limitLabelWidth)}${this.theme.fg("dim", resetText.trim())}`));
			}
		}
		if (limits.length === 0) rows.push(content(this.theme.fg("warning", "Rate-limit details unavailable")));
		if (this.data.usage.limitReached) rows.push(content(this.theme.fg("error", "OpenAI usage limit reached")));

		rows.push(content());
		rows.push(content(this.theme.fg("dim", "Enter or Esc to close")));
		rows.push(border(`╰${"─".repeat(innerWidth)}╯`));
		return rows;
	}
}
