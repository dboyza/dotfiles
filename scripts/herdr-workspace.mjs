#!/usr/bin/env node
// Open a project workspace with an agent, Neovim, and a persistent right-hand tree.
import { execFileSync } from 'node:child_process';
import { accessSync, constants, realpathSync, statSync } from 'node:fs';
import { basename, delimiter, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// Section: Herdr commands and reproducible plugin installation
const reviewrRef = 'c9a187ff2e701d1619be2ed22d101a6225916cd6'; // Reviewr 0.44.0.
function herdr(args) {
  const output = execFileSync('herdr', args, {
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

// Section: New workspace construction
export function createWorkspace(directory, agent, invoke = herdr, focus = true) {
  if (!['pi', 'claude', 'codex', 'opencode'].includes(agent)) throw new Error('Agent must be pi, claude, codex, or opencode.');
  const cwd = realpathSync(directory);
  if (!statSync(cwd).isDirectory()) throw new Error('Project path must be a directory.');
  const created = invoke(['workspace', 'create', '--cwd', cwd, '--label', basename(cwd), '--no-focus']);
  const workspace = created.workspace.workspace_id;
  try {
    const left = created.root_pane.pane_id;
    const right = invoke(['pane', 'split', left, '--direction', 'right', '--ratio', '0.4', '--cwd', cwd, '--no-focus']).pane.pane_id;
    invoke(['pane', 'rename', left, agent]);
    invoke(['pane', 'rename', right, 'Editor']);
    invoke(['pane', 'run', right, "nvim --cmd 'let g:dotfiles_workspace = 1'"]);
    invoke(['pane', 'run', left, agent]);
    if (focus) invoke(['workspace', 'focus', workspace]);
    return { workspace, agentPane: left, editorPane: right };
  } catch (error) {
    throw new Error(`Workspace ${workspace} was kept for recovery: ${error.message}`);
  }
}

// Section: Command-line entry point
function executable(name) {
  return (process.env.PATH || '').split(delimiter).some(directory => {
    try { accessSync(join(directory, name), constants.X_OK); return true; } catch { return false; }
  });
}
export function main(args) {
  if (args.includes('--help')) {
    console.log('Usage: herdr-workspace [directory] [pi|claude|codex|opencode]\n       herdr-workspace --install-reviewr\nRun herdr first. Each launch creates a new workspace in the current Herdr session.');
    return;
  }
  if (process.platform === 'win32') throw new Error('Run this workspace launcher inside WSL. Reviewr requires Linux or macOS.');
  if (!executable('herdr')) throw new Error('Install and launch Herdr first.');
  if (args.length === 1 && args[0] === '--install-reviewr') return installReviewr();
  if (args.length > 2 || args.some(arg => arg.startsWith('--'))) throw new Error('Use herdr-workspace --help for usage.');
  const agent = args[1] || 'codex';
  for (const command of ['nvim', agent]) if (!executable(command)) throw new Error(`Missing command: ${command}`);
  const result = createWorkspace(resolve(args[0] || '.'), agent);
  console.log(`Opened ${result.workspace}: ${agent} | Neovim | files. Reviewr: Ctrl+A, then v.`);
}
if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { main(process.argv.slice(2)); }
  catch (error) { console.error(`herdr-workspace: ${error.message}`); process.exitCode = 1; }
}
