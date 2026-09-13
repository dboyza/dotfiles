import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { stripVTControlCharacters } from "node:util";
import { adapterStatus, homePath, renderStatusline, singleLine } from "../pi/extensions/codex-statusline/render.mjs";

// Unit layout fixtures are ASCII; the real Pi TUI smoke test covers terminal-cell widths.
const display = {
  visibleWidth: (text) => stripVTControlCharacters(text).length,
  truncateToWidth(text, width, ellipsis = "…") {
    const plain = stripVTControlCharacters(text);
    return plain.length <= width ? text : plain.slice(0, Math.max(0, width - ellipsis.length)) + (width ? ellipsis : "");
  },
};
const sample = {
  model: "gpt-6-astra", thinking: "medium", cwd: "/home/test/code/dotfiles/agents/skills/readme-creation",
  home: "/home/test", codex: true, weekly: 61, fast: false, branch: "main", details: [],
};

test("matches the reference row with a real branch instead of the cosmetic label", () => {
  const lines = renderStatusline(sample, 150, display).map(stripVTControlCharacters);
  assert.deepEqual(lines, [" gpt-6-astra medium · ~/code/dotfiles/agents/skills/readme-creation · weekly 61% left · Fast off · main"]);
});

test("abbreviates only descendants of home on POSIX, WSL, Windows, and UNC paths", () => {
  assert.equal(homePath("/home/test", "/home/test"), "~");
  assert.equal(homePath("/home/test/code", "/home/test"), "~/code");
  assert.equal(homePath("/home/test-other/code", "/home/test"), "/home/test-other/code");
  assert.equal(homePath("/mnt/c/code", "/home/test"), "/mnt/c/code");
  assert.equal(homePath("C:\\Users\\Test\\code", "c:\\users\\test"), "~/code");
  assert.equal(homePath("D:\\code", "C:\\Users\\Test"), "D:\\code");
  assert.equal(homePath("\\\\host\\share\\home\\code", "\\\\host\\share\\home"), "~/code");
});

test("never invents quota or fast state and omits Codex fields for other providers", () => {
  const unknown = stripVTControlCharacters(renderStatusline({ ...sample, weekly: undefined, fast: undefined }, 150, display)[0]);
  assert.match(unknown, /weekly unavailable · Fast \?/);
  for (const weekly of [NaN, Infinity, -1, 101]) {
    assert.match(stripVTControlCharacters(renderStatusline({ ...sample, weekly }, 150, display)[0]), /weekly unavailable/);
  }
  const other = stripVTControlCharacters(renderStatusline({ ...sample, codex: false, branch: undefined }, 150, display)[0]);
  assert.doesNotMatch(other, /weekly|Fast|main/);
});

test("extracts the pinned adapter's weekly status without hiding errors", () => {
  assert.deepEqual(adapterStatus("\x1b[35mCodex adapter\x1b[0m V: low • notebook mode • weekly: 61% left"), { weekly: 61, detail: undefined });
  assert.equal(adapterStatus("Codex adapter • weekly: 0% left").weekly, 0);
  assert.equal(adapterStatus("Codex adapter • weekly: 101% left").weekly, undefined);
  assert.equal(adapterStatus("Codex adapter • extra tools: apply_patch, view_image").detail, undefined);
  for (const text of ["Codex adapter off: unavailable tools (exec)", "New adapter format"]) {
    assert.equal(adapterStatus(text).detail, text);
  }
});

test("keeps cache diagnostics and unrelated extension statuses on separate rows", () => {
  const lines = renderStatusline({ ...sample, details: ["Codex Cache • MISS • WS full", "Browser disconnected"] }, 150, display).map(stripVTControlCharacters);
  assert.equal(lines.length, 3);
  assert.match(lines[1], /MISS/);
  assert.equal(lines[2], " Browser disconnected");
});

test("shortens the directory first and never overflows even very narrow terminals", () => {
  for (let width = 1; width <= 160; width++) {
    for (const line of renderStatusline(sample, width, display)) assert.ok(display.visibleWidth(line) <= width);
  }
  assert.deepEqual(renderStatusline(sample, 0, display), []);
  const compact = stripVTControlCharacters(renderStatusline(sample, 80, display)[0]);
  assert.match(compact, /weekly 61% left · Fast off · main$/);
});

test("removes terminal escapes, controls, and bidi overrides from dynamic text", () => {
  assert.equal(singleLine("a\x1b[2Jb\n\t\u202Ec"), "ab c");
  assert.equal(singleLine("👩‍💻"), "👩‍💻", "preserve legitimate emoji joiners");
  const line = stripVTControlCharacters(renderStatusline({ ...sample, branch: "feature\n\x1b[2Jbad\u202E" }, 150, display)[0]);
  assert.doesNotMatch(line, /[\p{Cc}\p{Cf}]/u);
});

test("shared instructions retain quality checks while requiring approval for unrelated work", () => {
  const instructions = readFileSync(new URL("../agents/global/AGENTS.md", import.meta.url), "utf8");
  assert.match(instructions, /Fix problems caused by or blocking the requested change/);
  assert.match(instructions, /Report unrelated issues and expand scope only with approval/);
  assert.doesNotMatch(instructions, /even if it is not caused by|even if it is not directly related/);
});
