import { posix, win32 } from "node:path";
import { stripVTControlCharacters } from "node:util";

// The reference footer's palette, independent of transcript/tool colors.
export const COLORS = {
  model: [238, 212, 159],
  directory: [166, 218, 149],
  quota: [237, 135, 150],
  fast: [198, 160, 246],
  branch: [165, 173, 203],
  separator: [165, 173, 203],
};

export function singleLine(value = "") {
  return stripVTControlCharacters(String(value)).replace(/[\p{Cc}\u061c\u200e\u200f\u202a-\u202e\u2066-\u2069]/gu, " ").replace(/ +/g, " ").trim();
}

export function homePath(cwd, home) {
  if (!home) return singleLine(cwd);
  const paths = /^[A-Za-z]:[\\/]|^\\\\/.test(cwd) ? win32 : posix;
  const relative = paths.relative(home, cwd);
  if (!relative) return "~";
  if (relative === ".." || relative.startsWith(`..${paths.sep}`) || paths.isAbsolute(relative)) {
    return singleLine(cwd);
  }
  return singleLine(`~/${relative.replaceAll(paths.sep, "/")}`);
}

export function adapterStatus(text) {
  const plain = singleLine(text);
  const value = /\bweekly:\s*(\d+(?:\.\d+)?)% left\b/.exec(plain)?.[1];
  const weekly = value === undefined ? undefined : Number(value);
  // Keep nonstandard or failure statuses visible rather than masking them.
  const normal = /^Codex adapter(?: V: \S+)?(?: • .*)?$/.test(plain);
  return {
    weekly: weekly !== undefined && weekly >= 0 && weekly <= 100 ? weekly : undefined,
    detail: normal ? undefined : plain || undefined,
  };
}

export function color(role, text) {
  return `\x1b[38;2;${COLORS[role].join(";")}m${text}\x1b[39m`;
}

export function renderStatusline(state, width, { truncateToWidth, visibleWidth }) {
  if (width <= 0) return [];
  const join = (segments) => segments.filter(Boolean).join(color("separator", " · "));
  const model = color("model", singleLine(`${state.model || "no-model"}${state.thinking ? ` ${state.thinking}` : ""}`));
  const suffix = [];
  if (state.codex) {
    const weekly = state.weekly;
    const valid = Number.isFinite(weekly) && weekly >= 0 && weekly <= 100;
    suffix.push(color("quota", valid ? `weekly ${Math.round(weekly)}% left` : "weekly unavailable"));
    suffix.push(color("fast", `Fast ${state.fast === undefined ? "?" : state.fast ? "on" : "off"}`));
  }
  if (state.branch) suffix.push(color("branch", singleLine(state.branch)));
  // Shorten the directory first so quota and branch remain visible on ordinary terminals.
  const fixedWidth = visibleWidth(join([model, ...suffix])) + 3;
  const pathBudget = Math.max(1, width - 2 - fixedWidth);
  const directory = color("directory", truncateToWidth(homePath(state.cwd, state.home), pathBudget, "…"));
  const lines = [truncateToWidth(` ${join([model, directory, ...suffix])}`, width, "…")];
  // Diagnostics and extension warnings are not discarded to make the main row fit.
  for (const detail of state.details ?? []) {
    const text = singleLine(detail);
    if (text) lines.push(truncateToWidth(` ${color(/\bMISS\b|failed|unavailable|error/i.test(text) ? "quota" : "branch", text)}`, width, "…"));
  }
  return lines;
}
