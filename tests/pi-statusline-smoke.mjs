import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { homedir, platform, tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { setTimeout as delay } from "node:timers/promises";

const cli = process.argv[2];
if (platform() !== "darwin" || !cli) {
  console.log("Pi statusline TUI smoke skipped: macOS and an explicit Pi CLI path are required.");
  process.exit(0);
}
assert.ok(existsSync(cli), "Pi CLI path must exist");
const repo = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const adapter = process.argv[3] ?? join(homedir(), ".pi/agent/npm/node_modules/@howaboua/pi-codex-conversion");
assert.equal(JSON.parse(readFileSync(join(adapter, "package.json"), "utf8")).version, "3.0.34", "Revalidate the adapter integration before changing this pin");
const root = mkdtempSync(join(tmpdir(), "pi-statusline-smoke."));
const agent = join(root, "agent");
const workspace = join(root, "workspace");
const socket = `pi-footer-${process.pid}`;
const environment = { PATH: process.env.PATH, HOME: root, TERM: "xterm-256color", LANG: "en_US.UTF-8" };
const run = (command, args) => execFileSync(command, args, { env: environment, encoding: "utf8", timeout: 15000 });
const tmux = (...args) => run("tmux", ["-L", socket, ...args]);
const json = (path, value) => writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
const quote = (text) => `'${text.replaceAll("'", "'\\''")}'`;
const pane = () => tmux("capture-pane", "-p", "-t", "footer");
async function waitFor(pattern) {
  for (let attempt = 0; attempt < 100; attempt++) {
    const text = pane();
    if (pattern.test(text)) return text;
    await delay(100);
  }
  assert.fail(`Timed out waiting for ${pattern}:\n${pane()}`);
}
async function command(text) {
  tmux("send-keys", "-t", "footer", "-l", text);
  tmux("send-keys", "-t", "footer", "Enter");
  await delay(250);
}

try {
  mkdirSync(agent);
  mkdirSync(workspace);
  run("git", ["-C", workspace, "init", "-q", "-b", "main"]);
  writeFileSync(join(workspace, "AGENTS.md"), "# Offline footer fixture\n");
  json(join(agent, "settings.json"), {
    packages: [adapter], extensions: [join(repo, "pi/extensions/codex-statusline"), join(repo, "tests/fixtures/pi-statusline.ts")],
    themes: [join(repo, "pi/themes/rose-pine-moon.json")], theme: "rose-pine-moon", tuiMode: "fullscreen",
    defaultProvider: "openai-codex", defaultModel: "gpt-6-astra", defaultThinkingLevel: "high", quietStartup: true,
    lastChangelogVersion: "0.85.1", npmCommand: ["npm", "--ignore-scripts", "--omit=dev", "--legacy-peer-deps"],
  });
  json(join(agent, "models.json"), { providers: {
    "openai-codex": { apiKey: "not-a-real-credential", baseUrl: "https://chatgpt.com/backend-api/codex", api: "openai-codex-responses", models: [{ id: "gpt-6-astra", reasoning: true, input: ["text", "image"], contextWindow: 200000, maxTokens: 8192 }] },
    offline: { apiKey: "not-a-real-credential", baseUrl: "http://127.0.0.1:9", api: "openai-completions", models: [{ id: "fixture-model", reasoning: false }] },
  } });
  const configPath = join(agent, "pi-codex-conversion.json");
  const config = { executionMode: "notebook", tools: { applyPatchOnly: true, viewImageOnly: true }, openai: { fast: false, cacheDiagnostics: "status" } };
  json(configPath, config);
  const launch = ["env", `PI_CODING_AGENT_DIR=${agent}`, "PI_OFFLINE=1", "PI_TELEMETRY=0", "/usr/bin/sandbox-exec", "-p", "(version 1)(allow default)(deny network*)", process.execPath, resolve(cli), "--no-session", "--no-skills", "--no-context-files", "--no-approve"].map(quote).join(" ");
  tmux("-f", "/dev/null", "new-session", "-d", "-s", "footer", "-x", "150", "-y", "35", "-c", workspace, launch);
  await waitFor(/gpt-6-astra high .*weekly unavailable .*Fast off .*main/);
  assert.doesNotMatch(pane(), /integration unavailable|Failed to load extension/);
  await command("/footer-fixture");
  await waitFor(/weekly 61% left .*Fast off .*main/);
  assert.match(pane(), /Unicode cell widths 0-180/);
  assert.match(pane(), /Codex Cache • HIT • WS delta/);
  const capture = tmux("capture-pane", "-e", "-p", "-t", "footer");
  const evidence = process.env.PI_STATUSLINE_CAPTURE;
  if (evidence) writeFileSync(evidence, capture);
  json(configPath, { ...config, openai: { ...config.openai, fast: true } });
  await waitFor(/Fast on/);
  await command("/footer-fixture medium");
  await waitFor(/gpt-6-astra medium/);
  run("git", ["-C", workspace, "symbolic-ref", "HEAD", "refs/heads/footer-test"]);
  await waitFor(/Fast on .*footer-test/);
  tmux("resize-window", "-t", "footer", "-x", "80", "-y", "35");
  await waitFor(/weekly 61% left .*Fast on .*footer-test/);
  await command("/statusline");
  await waitFor(/\(auto\)/);
  await command("/statusline");
  await waitFor(/weekly 61% left .*Fast on/);
  mkdirSync(join(workspace, ".pi"));
  json(join(workspace, ".pi/pi-codex-conversion.json"), { openai: { fast: false } });
  await command("/reload");
  await waitFor(/weekly unavailable .*Fast on/); // Untrusted project overrides must not win.
  await command("/footer-fixture other");
  await waitFor(/fixture-model/);
  const lastLines = pane().trimEnd().split("\n").slice(-3).join("\n");
  assert.doesNotMatch(lastLines, /weekly|Fast|gpt-6-astra/);
  console.log("PASS: real Pi TUI load, adapter readers, quota/cache rendering, config watch, reasoning, Git updates, resize, toggle, reload, untrusted config, provider switch, and Unicode widths.");
} finally {
  try { tmux("kill-server"); } catch { /* The isolated server may already be closed. */ }
  rmSync(root, { recursive: true, force: true });
}
