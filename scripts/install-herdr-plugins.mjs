#!/usr/bin/env node
// Install the pinned Reviewr plugin and leave Herdr's new spaces at their default layout.
import { execFileSync, spawnSync } from 'node:child_process';
import { realpathSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

// Section: Herdr command boundary
const source = fileURLToPath(import.meta.url);
const reviewrRef = 'c9a187ff2e701d1619be2ed22d101a6225916cd6'; // Reviewr 0.44.0.
const retiredLayout = 'dotfiles.workspace';
const herdrBin = process.env.HERDR_BIN_PATH || 'herdr';
const env = { ...process.env, DOTFILES_TOOL_UPDATE: '0' };
function herdr(args) {
  const result = spawnSync(herdrBin, args, { encoding: 'utf8', env, stdio: ['ignore', 'pipe', 'pipe'] });
  if (result.error?.code === 'ENOENT') throw new Error('Install and launch Herdr first.');
  if (result.error) throw result.error;
  if (result.status !== 0) {
    // Herdr reports command failures as a JSON line on stderr.
    let failure;
    try { failure = JSON.parse(result.stderr.trim().split('\n').at(-1)).error?.message; } catch {}
    throw new Error(failure || `herdr ${args.join(' ')} failed: ${result.stderr.trim() || `exit ${result.status}`}`);
  }
  process.stderr.write(result.stderr);
  if (!result.stdout.trim()) return {}; // Mutations acknowledge success without JSON.
  const response = JSON.parse(result.stdout);
  if (response.error) throw new Error(response.error.message);
  return response.result;
}

// Section: Plugin reconciliation
export function installPlugins(invoke = herdr) {
  const { plugins } = invoke(['plugin', 'list', '--json']);
  if (!plugins.some(plugin => plugin.plugin_id === 'persiyanov.reviewr')) {
    execFileSync(herdrBin, ['plugin', 'install', 'persiyanov/herdr-reviewr', '--ref', reviewrRef, '--yes'],
      { stdio: 'inherit', env });
  }
  // Earlier checkouts linked a hook that opened Neovim and a file tree in every new space.
  if (plugins.some(plugin => plugin.plugin_id === retiredLayout)) invoke(['plugin', 'unlink', retiredLayout]);
}

if (process.argv[1] && realpathSync(process.argv[1]) === source) {
  try {
    if (process.platform === 'win32') throw new Error('Run this inside WSL. Reviewr requires Linux or macOS.');
    installPlugins();
  } catch (error) {
    console.error(`install-herdr-plugins: ${error.message}`);
    process.exitCode = 1;
  }
}
