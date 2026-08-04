import { Buffer } from "node:buffer";

type JsonObject = Record<string, unknown>;

export type OpenAIIdentity = {
	accountId?: string;
	email?: string;
	plan?: string;
};

export type UsageWindowStatus = {
	label: string;
	usedPercent: number;
	remainingPercent: number;
	resetAt?: number;
};

export type OpenAIUsageStatus = {
	plan: string;
	windows: UsageWindowStatus[];
	additionalLimits: Array<{ name: string; windows: UsageWindowStatus[] }>;
	credits?: string;
	limitReached: boolean;
};

function asObject(value: unknown): JsonObject | undefined {
	return value !== null && typeof value === "object" && !Array.isArray(value) ? (value as JsonObject) : undefined;
}

function asNumber(value: unknown): number | undefined {
	return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function asString(value: unknown): string | undefined {
	return typeof value === "string" && value.length > 0 ? value : undefined;
}

function formatDuration(seconds: number): string {
	if (seconds === 18_000) return "5-hour";
	if (seconds === 86_400) return "Daily";
	if (seconds === 604_800) return "Weekly";
	if (seconds >= 2_419_200 && seconds <= 2_678_400) return "Monthly";
	if (seconds % 86_400 === 0) return `${seconds / 86_400}-day`;
	if (seconds % 3_600 === 0) return `${seconds / 3_600}-hour`;
	return `${Math.round(seconds / 60)}-minute`;
}

function formatRemaining(resetAt: number, nowMs: number): string {
	const remainingSeconds = Math.max(0, Math.round(resetAt - nowMs / 1000));
	const days = Math.floor(remainingSeconds / 86_400);
	const hours = Math.floor((remainingSeconds % 86_400) / 3_600);
	const minutes = Math.floor((remainingSeconds % 3_600) / 60);
	if (days > 0) return `${days}d ${hours}h`;
	if (hours > 0) return `${hours}h ${minutes}m`;
	return `${minutes}m`;
}

function formatWindow(window: JsonObject, nowMs: number): string | undefined {
	const usedPercent = asNumber(window.used_percent);
	const durationSeconds = asNumber(window.limit_window_seconds);
	if (usedPercent === undefined || durationSeconds === undefined) return undefined;

	const label = formatDuration(durationSeconds);
	const remainingPercent = Math.max(0, 100 - usedPercent);
	const resetAt = asNumber(window.reset_at);
	const resetText = resetAt === undefined
		? ""
		: `, resets ${new Date(resetAt * 1000).toLocaleString()} (in ${formatRemaining(resetAt, nowMs)})`;
	return `${label}: ${usedPercent}% used, ${remainingPercent}% left${resetText}`;
}

function formatRateLimit(value: unknown, nowMs: number): string[] {
	const rateLimit = asObject(value);
	if (!rateLimit) return [];
	const lines: string[] = [];
	const primary = asObject(rateLimit.primary_window);
	const secondary = asObject(rateLimit.secondary_window);
	if (primary) {
		const line = formatWindow(primary, nowMs);
		if (line) lines.push(line);
	}
	if (secondary) {
		const line = formatWindow(secondary, nowMs);
		if (line) lines.push(line);
	}
	if (rateLimit.limit_reached === true) lines.push("Limit reached");
	return lines;
}

function parseUsageWindow(value: unknown): UsageWindowStatus | undefined {
	const window = asObject(value);
	if (!window) return undefined;
	const usedPercent = asNumber(window.used_percent);
	const durationSeconds = asNumber(window.limit_window_seconds);
	if (usedPercent === undefined || durationSeconds === undefined) return undefined;
	return {
		label: formatDuration(durationSeconds),
		usedPercent,
		remainingPercent: Math.max(0, 100 - usedPercent),
		resetAt: asNumber(window.reset_at),
	};
}

function parseUsageWindows(value: unknown): UsageWindowStatus[] {
	const rateLimit = asObject(value);
	if (!rateLimit) return [];
	return [parseUsageWindow(rateLimit.primary_window), parseUsageWindow(rateLimit.secondary_window)].filter(
		(window): window is UsageWindowStatus => window !== undefined,
	);
}

export function parseOpenAIUsageStatus(payload: unknown): OpenAIUsageStatus {
	const root = asObject(payload);
	if (!root) throw new Error("OpenAI returned an invalid usage response");
	const additionalLimits: OpenAIUsageStatus["additionalLimits"] = [];
	if (Array.isArray(root.additional_rate_limits)) {
		for (const value of root.additional_rate_limits) {
			const additional = asObject(value);
			if (!additional) continue;
			additionalLimits.push({
				name: asString(additional.limit_name) ?? "Additional limit",
				windows: parseUsageWindows(additional.rate_limit),
			});
		}
	}
	const credits = asObject(root.credits);
	const rateLimit = asObject(root.rate_limit);
	return {
		plan: asString(root.plan_type) ?? "unknown",
		windows: parseUsageWindows(root.rate_limit),
		additionalLimits,
		credits: credits?.unlimited === true ? "unlimited" : asString(credits?.balance),
		limitReached: rateLimit?.limit_reached === true || asString(root.rate_limit_reached_type) !== undefined,
	};
}

export function extractOpenAIIdentity(accessToken: string): OpenAIIdentity {
	try {
		const payloadPart = accessToken.split(".")[1];
		if (!payloadPart) return {};
		const normalized = payloadPart.replace(/-/g, "+").replace(/_/g, "/");
		const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
		const payload = JSON.parse(Buffer.from(padded, "base64").toString("utf8")) as JsonObject;
		const auth = asObject(payload["https://api.openai.com/auth"]);
		const profile = asObject(payload["https://api.openai.com/profile"]);
		return {
			accountId: asString(auth?.chatgpt_account_id),
			email: asString(profile?.email),
			plan: asString(auth?.chatgpt_plan_type),
		};
	} catch {
		return {};
	}
}

export function extractAccountId(accessToken: string): string | undefined {
	return extractOpenAIIdentity(accessToken).accountId;
}

export function formatOpenAIUsage(payload: unknown, nowMs = Date.now()): string[] {
	const root = asObject(payload);
	if (!root) throw new Error("OpenAI returned an invalid usage response");

	const plan = asString(root.plan_type) ?? "unknown";
	const lines = [`OpenAI Codex usage (${plan} plan)`];
	const primaryLines = formatRateLimit(root.rate_limit, nowMs);
	lines.push(...(primaryLines.length > 0 ? primaryLines : ["Main rate limit: unavailable"]));

	if (Array.isArray(root.additional_rate_limits)) {
		for (const value of root.additional_rate_limits) {
			const additional = asObject(value);
			if (!additional) continue;
			const name = asString(additional.limit_name) ?? "Additional limit";
			for (const line of formatRateLimit(additional.rate_limit, nowMs)) {
				lines.push(`${name} - ${line}`);
			}
		}
	}

	const credits = asObject(root.credits);
	if (credits) {
		if (credits.unlimited === true) lines.push("Credits: unlimited");
		else if (asString(credits.balance) !== undefined) lines.push(`Credits: ${asString(credits.balance)}`);
		else if (credits.has_credits === false) lines.push("Credits: none");
	}

	const spendControl = asObject(root.spend_control);
	if (spendControl?.reached === true) lines.push("Spending limit reached");
	const reachedType = asString(root.rate_limit_reached_type);
	if (reachedType) lines.push(`Limit state: ${reachedType}`);
	return lines;
}
