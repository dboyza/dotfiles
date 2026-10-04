// Exercise new-space layout ownership, picker choices, and plugin installation.
import assert from 'node:assert/strict';
import { mkdtempSync, realpathSync, rmSync, writeFileSync, readFileSync, symlinkSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { createWorkspace, applyLayout, agentChoice, installReviewr } from '../scripts/herdr-workspace.mjs';

// Section: Fake Herdr boundary with real project paths
function fixture(t, fail) {
  const directory = realpathSync(mkdtempSync(join(tmpdir(), "workspace with ' spaces ")));
  t.after(() => rmSync(directory, { recursive: true }));
  const calls = [];
  const panes = [{ pane_id: 'w9:p1', cwd: directory }];
  const invoke = args => {
    calls.push(args);
    if (fail?.(args)) throw new Error('fixture failure');
    if (args[0] === 'workspace' && args[1] === 'create') return { workspace: { workspace_id: 'w9' } };
    if (args[0] === 'pane' && args[1] === 'list') return { panes };
    if (args[1] === 'process-info') return { process_info: { shell_pid: 123, foreground_processes: [{ pid: 123 }] } };
    if (args[1] === 'split') {
      panes.push({ pane_id: 'w9:p2', cwd: directory });
      return { pane: panes[1] };
    }
    return {};
  };
  return { directory, calls, panes, invoke };
}

test('launcher creates a space and leaves all layout work to the event hook', t => {
  const { directory, calls, invoke } = fixture(t);
  assert.equal(createWorkspace(directory, undefined, invoke), 'w9');
  assert.equal(calls.length, 1);
  assert.equal(calls[0][3], directory);
  assert(calls[0].includes('DOTFILES_WORKSPACE_AGENT='));
  createWorkspace(directory, 'pi', invoke);
  assert(calls[1].includes('DOTFILES_WORKSPACE_AGENT=pi'));
});

test('creation hook targets only the event workspace and does not duplicate its layout', async t => {
  const { directory, calls, invoke } = fixture(t);
  assert.deepEqual(await applyLayout('w9', invoke), { workspace: 'w9', agentPane: 'w9:p1', editorPane: 'w9:p2' });
  const split = calls.find(args => args[1] === 'split');
  assert.equal(split[2], 'w9:p1');
  assert.equal(split[split.indexOf('--cwd') + 1], directory);
  const runs = calls.filter(args => args[1] === 'run');
  assert.deepEqual(runs[0], ['pane', 'run', 'w9:p2', "nvim --cmd 'let g:dotfiles_workspace = 1'"]);
  assert.equal(runs[1][2], 'w9:p1');
  assert.match(runs[1][3], /--pick-agent$/);
  await applyLayout('w9', invoke);
  assert.equal(calls.filter(args => args[1] === 'split').length, 1);
  assert(!calls.some(args => args[1] === 'focus'));
});

test('occupied panes and malformed events are preserved without layout mutation', async t => {
  const { invoke, calls } = fixture(t);
  const occupied = args => args[1] === 'process-info'
    ? { process_info: { shell_pid: 123, foreground_processes: [{ pid: 456 }] } } : invoke(args);
  await applyLayout('w9', occupied);
  await assert.rejects(applyLayout(undefined, invoke), /no workspace ID/);
  assert(!calls.some(args => args[1] === 'split' || args[1] === 'run'));
});

test('invalid agent and missing directory fail before workspace creation', t => {
  const { directory, calls, invoke } = fixture(t);
  assert.throws(() => createWorkspace(directory, 'codex; touch /tmp/unsafe', invoke), /Agent must/);
  assert.throws(() => createWorkspace(join(directory, 'missing'), 'pi', invoke), /ENOENT/);
  assert.equal(calls.length, 0);
});

test('failed setup preserves the workspace and identifies it for recovery', async t => {
  const { calls, invoke } = fixture(t, args => args[1] === 'run');
  await assert.rejects(applyLayout('w9', invoke), /Workspace w9 was kept for recovery/);
  assert(!calls.some(args => args[1] === 'close' || args[1] === 'focus'));
});

test('picker accepts numbers and names with no implicit default', () => {
  assert.equal(agentChoice('1'), 'codex');
  assert.equal(agentChoice('2'), 'claude');
  assert.equal(agentChoice('3'), 'pi');
  assert.equal(agentChoice('4'), 'opencode');
  assert.equal(agentChoice(' PI '), 'pi');
  for (const value of ['', '5', '01', 'codex; date']) assert.equal(agentChoice(value), undefined);
  assert.equal(agentChoice('q'), null);
});

test('existing Reviewr installation is preserved', () => {
  installReviewr(() => ({ plugins: [{ plugin_id: 'persiyanov.reviewr' }] }));
});

// Section: Real CLI parsing against an isolated Herdr executable
// Mutation acknowledgments are empty in Herdr even though discovery returns JSON.
test('CLI enables the layout hook and installs missing Reviewr from the pinned source', { skip: process.platform === 'win32' }, t => {
  const { directory } = fixture(t);
  const log = join(directory, 'calls.jsonl');
  const fake = join(directory, 'herdr');
  writeFileSync(fake, `#!/usr/bin/env node
import { appendFileSync } from 'node:fs';
const args = process.argv.slice(2);
appendFileSync(process.env.WORKSPACE_TEST_LOG, JSON.stringify(args) + '\\n');
if (args[0] === 'workspace' && args[1] === 'create') console.log(JSON.stringify({result:{workspace:{workspace_id:'w9'}}}));
if (args[0] === 'plugin' && args[1] === 'list') console.log(JSON.stringify({result:{plugins:[]}}));
`, { mode: 0o755 });
  for (const tool of ['codex', 'nvim']) symlinkSync(fake, join(directory, tool));
  const env = { ...process.env, PATH: `${directory}:${process.env.PATH}`, HERDR_BIN_PATH: '', WORKSPACE_TEST_LOG: log };
  const launcher = fileURLToPath(new URL('../scripts/herdr-workspace.mjs', import.meta.url));
  const output = execFileSync(process.execPath, [launcher, directory], { env, encoding: 'utf8' });
  assert.match(output, /Opened w9/);
  execFileSync(process.execPath, [launcher, '--install-plugins'], { env });
  const calls = readFileSync(log, 'utf8').trim().split('\n').map(line => JSON.parse(line));
  assert(calls.find(args => args[1] === 'create').includes('DOTFILES_WORKSPACE_AGENT='));
  assert(!calls.some(args => args[1] === 'split'));
  assert.deepEqual(calls.find(args => args[1] === 'install'), ['plugin', 'install', 'persiyanov/herdr-reviewr', '--ref', 'c9a187ff2e701d1619be2ed22d101a6225916cd6', '--yes']);
  assert.equal(calls.at(-1)[1], 'link');
  assert.equal(calls.at(-1).at(-1), '--enabled');
});
