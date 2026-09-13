import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { platform, tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { setTimeout as delay } from "node:timers/promises";

const cli = process.argv[2];
if (!cli || platform() !== "darwin") {
  console.log("Scroll TUI smoke skipped: requires macOS, tmux, and an explicit Pi CLI path.");
  process.exit(0);
}
const repo = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const root = mkdtempSync(join(tmpdir(), "pi-scroll."));
const agent = join(root, "agent");
const socket = `pi-scroll-${process.pid}`;
const env = { PATH: process.env.PATH, HOME: root, TERM: "xterm-256color", LANG: "en_US.UTF-8" };
const tmux = (...args) => execFileSync("tmux", ["-L", socket, ...args], { env, encoding: "utf8", timeout: 15000 });
const quote = (s) => `'${s.replaceAll("'", "'\\''")}'`;
const json = (path, data) => writeFileSync(path, JSON.stringify(data));
const pane = () => tmux("capture-pane", "-p", "-t", "scroll");
async function waitFor(predicate) {
  for (let i = 0; i < 100; i++) {
    const text = pane();
    if (predicate(text)) return text;
    await delay(100);
  }
  assert.fail(`Timed out waiting for terminal state:\n${pane()}`);
}
async function command(text) {
  tmux("send-keys", "-t", "scroll", "-l", text);
  tmux("send-keys", "-t", "scroll", "Enter");
  await delay(300);
}
const firstRow = (text) => Number(/SCROLL_ROW_(\d+)/.exec(text)?.[1]);
async function measure(button, events = 10) {
  // Start within the document, away from the header and either scrolling boundary.
  tmux("send-keys", "-t", "scroll", "Home");
  await delay(200);
  tmux("send-keys", "-t", "scroll", "PageDown");
  await delay(200);
  const before = firstRow(pane());
  assert.ok(Number.isFinite(before));
  for (let i = 0; i < events; i++) tmux("send-keys", "-t", "scroll", "-l", `\x1b[<${button};10;10M`);
  await delay(300);
  return firstRow(pane()) - before;
}

try {
  mkdirSync(agent);
  const settings = { packages: [], extensions: [join(repo, "tests/fixtures/pi-scroll.ts")], tuiMode: "fullscreen", quietStartup: true, lastChangelogVersion: "0.85.1" };
  json(join(agent, "settings.json"), settings);
  const launch = ["env", `PI_CODING_AGENT_DIR=${agent}`, "PI_OFFLINE=1", "PI_TELEMETRY=0", "/usr/bin/sandbox-exec", "-p", "(version 1)(allow default)(deny network*)", process.execPath, resolve(cli), "--no-session", "--no-context-files", "--no-skills", "--no-approve"].map(quote).join(" ");
  tmux("-f", "/dev/null", "new-session", "-d", "-s", "scroll", "-x", "100", "-y", "35", "-c", root, launch);
  await waitFor((text) => text.includes("Scroll fixture ready"));
  await command("/scroll-fixture");
  await waitFor((text) => text.includes("SCROLL_ROW_300"));
  assert.equal(await measure(65), 10);
  assert.equal(await measure(73), 50);
  console.log("REPRODUCED: 10 ordinary wheel events move 10 lines; Alt-wheel moves 50 lines.");
  if (process.env.PI_SCROLL_BASELINE_ONLY !== "1") {
    settings.extensions.push(join(repo, "pi/extensions/scroll-sensitivity"));
    json(join(agent, "settings.json"), settings);
    await command("/reload");
    await command("/scroll-speed fast");
    tmux("send-keys", "-t", "scroll", "End");
    await waitFor((text) => text.includes("Scrolling: fast"));
    assert.equal(await measure(65), 50, pane());
    assert.equal(await measure(64, 2), -10, "Upward scrolling must use the same step");
    assert.equal(await measure(73, 2), 50, "Alt-wheel retains its native fivefold multiplier");
    await command("/scroll-speed normal");
    assert.equal(await measure(65), 10);
    await command("/scroll-speed fast");
    await command("/reload");
    assert.equal(await measure(65), 50, "Reload must not compound the scroll step");
    settings.extensions.pop();
    json(join(agent, "settings.json"), settings);
    await command("/reload");
    assert.equal(await measure(65), 10, "Removing the extension restores the native step");
    console.log("PASS: 5x scrolling in both directions, native Alt multiplier, normal/fast controls, and reload.");
  }
} finally {
  try { tmux("kill-server"); } catch { /* Already closed. */ }
  rmSync(root, { recursive: true, force: true });
}
