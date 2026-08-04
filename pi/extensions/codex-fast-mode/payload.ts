export function applyCodexPriorityTier(payload: unknown): unknown {
	if (payload === null || typeof payload !== "object" || Array.isArray(payload)) return payload;
	return { ...(payload as Record<string, unknown>), service_tier: "priority" };
}
