#!/usr/bin/env node
// Give new Herdr spaces an agent picker, Neovim, and a persistent right-hand tree.
import { execFileSync, spawnSync } from 'node:child_process';
import { accessSync, constants, realpathSync, statSync } from 'node:fs';
import { basename, delimiter, dirname, join, resolve } from 'node:path';
import { createInterface } from 'node:readline/promises';
import { setTimeout as delay } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';

// Section: Herdr commands and reproducible plugin installation
const source = fileURLToPath(import.meta.url);
const pluginRoot = resolve(dirname(source), '../herdr/workspace');
const reviewrRef = 'c9a187ff2e701d1619be2ed22d101a6225916cd6'; // Reviewr 0.44.0.
const agents = ['codex', 'claude', 'pi', 'opencode'];
const agentPaneRatio = 3 / 7;
function herdr(args) {
  const output = execFileSync(process.env.HERDR_BIN_PATH || 'herdr', args, {
    encoding: 'utf8', env: { ...process.env, DOTFILES_TOOL_UPDATE: '0' },
    stdio: ['ignore', 'pipe', 'inherit'],
  });
  if (!output.trim()) return {}; // Pane commands can acknowledge success without JSON.
  const response = JSON.parse(output);
  if (response.error) throw new Error(JSON.stringify(response.error));
  if (!response.result) throw new Error('Herdr returned no result.');
  return response.result;
}
export function installReviewr(invoke = herdr) {
  const { plugins } = invoke(['plugin', 'list', '--json']);
  if (plugins.some(plugin => plugin.plugin_id === 'persiyanov.reviewr')) return;
  execFileSync('herdr', ['plugin', 'install', 'persiyanov/herdr-reviewr', '--ref', reviewrRef, '--yes'], {
    stdio: 'inherit', env: { ...process.env, DOTFILES_TOOL_UPDATE: '0' },
  });
}
export function installLayout(invoke = herdr) {
  const { plugins } = invoke(['plugin', 'list', '--json']);
  const installed = plugins.find(plugin => plugin.plugin_id === 'dotfiles.workspace');
  if (!installed?.enabled || installed.plugin_root !== pluginRoot) {
    invoke(['plugin', 'link', pluginRoot, '--enabled']);
  }
}

// Section: Workspace creation and automatic layout
export function createWorkspace(directory, agent, invoke = herdr) {
  if (agent && !agents.includes(agent)) throw new Error('Agent must be codex, claude, pi, or opencode.');
  const cwd = realpathSync(directory);
  if (!statSync(cwd).isDirectory()) throw new Error('Project path must be a directory.');
  // Clear inherited choices so each new space asks independently unless explicitly overridden.
  const created = invoke(['workspace', 'create', '--cwd', cwd, '--label', basename(cwd),
    '--env', `DOTFILES_WORKSPACE_AGENT=${agent || ''}`, '--focus']);
  return created.workspace.workspace_id;
}
export async function applyLayout(workspace, invoke = herdr) {
  if (!workspace) throw new Error('Workspace creation event has no workspace ID.');
  let left;
  // Creation events can precede the root shell's initialization; never target the focused pane.
  const startupAttempts = 50, startupPollMs = 100;
  for (let attempt = 0; attempt < startupAttempts; attempt++) {
    const { panes } = invoke(['pane', 'list', '--workspace', workspace]);
    if (panes.length > 1) return; // Already laid out or modified by the user.
    left = panes[0];
    if (left) {
      const { process_info: info } = invoke(['pane', 'process-info', '--pane', left.pane_id]);
      if (info.foreground_processes.some(process => process.pid === info.shell_pid)) break;
      if (info.foreground_processes.length) return; // Preserve occupied panes.
    }
    left = undefined;
    await delay(startupPollMs);
  }
  if (!left) throw new Error(`Workspace ${workspace}: root shell did not become available.`);
  try {
    const right = invoke(['pane', 'split', left.pane_id, '--direction', 'right', '--ratio', String(agentPaneRatio),
      '--cwd', left.cwd, '--no-focus']).pane.pane_id;
    invoke(['pane', 'rename', left.pane_id, 'Choose agent']);
    invoke(['pane', 'rename', right, 'Editor']);
    invoke(['pane', 'run', right, "nvim --cmd 'let g:dotfiles_workspace = 1'"]);
    const quotedSource = "'" + source.replaceAll("'", "'\\''") + "'";
    invoke(['pane', 'run', left.pane_id, `node ${quotedSource} --pick-agent`]);
    return { workspace, agentPane: left.pane_id, editorPane: right };
  } catch (error) {
    throw new Error(`Workspace ${workspace} was kept for recovery: ${error.message}`);
  }
}

// Section: Interactive agent selection inside the new space
export function agentChoice(answer) {
  const value = answer.trim().toLowerCase();
  if (value === 'q' || value === 'cancel') return null;
  if (/^[1-4]$/.test(value)) return agents[Number(value) - 1];
  return agents.includes(value) ? value : undefined;
}
async function pickAgent() {
  let selected = process.env.DOTFILES_WORKSPACE_AGENT;
  if (selected && !agents.includes(selected)) throw new Error('Invalid explicit workspace agent.');
  if (!selected) {
    if (!process.stdin.isTTY) throw new Error('The agent picker needs an interactive terminal.');
    console.log('\nChoose an agent\n\n  1  Codex\n  2  Claude Code\n  3  Pi\n  4  opencode\n  q  Stay at the shell\n');
    const input = createInterface({ input: process.stdin, output: process.stdout });
    const abort = new AbortController();
    input.on('SIGINT', () => abort.abort());
    input.on('close', () => abort.abort());
    try {
      while (!selected) {
        selected = agentChoice(await input.question('Agent [1-4 or name]: ', { signal: abort.signal }));
        if (selected === null) return;
        if (!selected) console.log('Choose 1-4, an agent name, or q.');
        else if (!executable(selected)) { console.log(`${selected} is not installed.`); selected = undefined; }
      }
    } catch (error) {
      if (error.code !== 'ABORT_ERR' && error.code !== 'ERR_USE_AFTER_CLOSE') throw error;
      return;
    } finally {
      input.close();
      if (!selected && process.env.HERDR_PANE_ID) herdr(['pane', 'rename', process.env.HERDR_PANE_ID, 'Shell']);
    }
  }
  if (process.env.HERDR_PANE_ID) herdr(['pane', 'rename', process.env.HERDR_PANE_ID, selected]);
  const env = { ...process.env };
  delete env.DOTFILES_WORKSPACE_AGENT;
  const result = spawnSync(selected, [], { stdio: 'inherit', env });
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
}

// Section: Command-line entry point
function executable(name) {
  return (process.env.PATH || '').split(delimiter).some(directory => {
    try { accessSync(join(directory, name), constants.X_OK); return true; } catch { return false; }
  });
}
export async function main(args) {
  if (args.includes('--help')) {
    console.log('Usage: herdr-workspace [directory] [codex|claude|pi|opencode]\n       herdr-workspace --install-plugins\nNew spaces show an agent picker beside Neovim. An explicit agent skips the picker.');
    return;
  }
  if (process.platform === 'win32') throw new Error('Run this workspace launcher inside WSL. Reviewr requires Linux or macOS.');
  if (args.length === 1 && args[0] === '--pick-agent') return pickAgent();
  if (args.length === 1 && args[0] === '--workspace-created') {
    const event = JSON.parse(process.env.HERDR_PLUGIN_EVENT_JSON || '{}');
    return applyLayout(event.data?.workspace?.workspace_id);
  }
  if (!executable('herdr')) throw new Error('Install and launch Herdr first.');
  if (args.length === 1 && ['--install-plugins', '--install-reviewr'].includes(args[0])) {
    installReviewr();
    return installLayout();
  }
  if (args.length > 2 || args.some(arg => arg.startsWith('--'))) throw new Error('Use herdr-workspace --help for usage.');
  for (const command of ['nvim', ...(args[1] ? [args[1]] : [])]) {
    if (!executable(command)) throw new Error(`Missing command: ${command}`);
  }
  installLayout();
  const workspace = createWorkspace(resolve(args[0] || '.'), args[1]);
  console.log(`Opened ${workspace}. The new-space hook opens the agent picker and editor. Reviewr: Ctrl+A, then v.`);
}
if (process.argv[1] && realpathSync(process.argv[1]) === source) {
  try { await main(process.argv.slice(2)); }
  catch (error) { console.error(`herdr-workspace: ${error.message}`); process.exitCode = 1; }
}
