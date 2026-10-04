// Exercise workspace ownership, argument safety, and recoverable partial failures.
import assert from 'node:assert/strict';
import { mkdtempSync, realpathSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { createWorkspace, installReviewr } from '../scripts/herdr-workspace.mjs';

// Section: Fake Herdr boundary with real project paths
function fixture(t, fail) {
  const directory = realpathSync(mkdtempSync(join(tmpdir(), "workspace with ' spaces ")));
  t.after(() => rmSync(directory, { recursive: true }));
  const calls = [];
  const invoke = args => {
    calls.push(args);
    if (fail?.(args)) throw new Error('fixture failure');
    if (args[0] === 'workspace' && args[1] === 'create') return { workspace: { workspace_id: 'w9' }, root_pane: { pane_id: 'w9:p1' } };
    if (args[0] === 'pane' && args[1] === 'split') return { pane: { pane_id: 'w9:p2' } };
    return {};
  };
  return { directory, calls, invoke };
}

test('only new panes receive commands, with explicit cwd and a scoped editor profile', t => {
  const { directory, calls, invoke } = fixture(t);
  assert.deepEqual(createWorkspace(directory, 'codex', invoke), { workspace: 'w9', agentPane: 'w9:p1', editorPane: 'w9:p2' });
  assert.equal(calls[0][3], directory);
  const split = calls.find(args => args[1] === 'split');
  assert.equal(split[2], 'w9:p1');
  assert.equal(split[split.indexOf('--cwd') + 1], directory);
  assert.deepEqual(calls.filter(args => args[1] === 'run'), [
    ['pane', 'run', 'w9:p2', "nvim --cmd 'let g:dotfiles_workspace = 1'"],
    ['pane', 'run', 'w9:p1', 'codex'],
  ]);
  assert.deepEqual(calls.at(-1), ['workspace', 'focus', 'w9']);
});

test('invalid agent and missing directory fail before workspace creation', t => {
  const { directory, calls, invoke } = fixture(t);
  assert.throws(() => createWorkspace(directory, 'codex; touch /tmp/unsafe', invoke), /Agent must/);
  assert.throws(() => createWorkspace(join(directory, 'missing'), 'pi', invoke), /ENOENT/);
  assert.equal(calls.length, 0);
});

test('failed setup preserves the workspace and identifies it for recovery', t => {
  const { directory, calls, invoke } = fixture(t, args => args[1] === 'run');
  assert.throws(() => createWorkspace(directory, 'pi', invoke), /Workspace w9 was kept for recovery/);
  assert(!calls.some(args => args[1] === 'close' || args[1] === 'focus'));
});

test('existing Reviewr installation is preserved without updating or reinstalling', () => {
  installReviewr(() => ({ plugins: [{ plugin_id: 'persiyanov.reviewr' }] }));
});

// Section: Real CLI parsing against an isolated Herdr executable
// Mutation acknowledgments are empty in Herdr even though discovery returns JSON.
test('CLI accepts empty acknowledgments and installs the pinned plugin when absent', { skip: process.platform === 'win32' }, async t => {
  const { writeFileSync, readFileSync, symlinkSync } = await import('node:fs');
  const { execFileSync } = await import('node:child_process');
  const { directory } = fixture(t);
  const log = join(directory, 'calls.jsonl');
  const fake = join(directory, 'herdr');
  writeFileSync(fake, `#!/usr/bin/env node
import { appendFileSync } from 'node:fs';
const args = process.argv.slice(2);
appendFileSync(process.env.WORKSPACE_TEST_LOG, JSON.stringify(args) + '\\n');
if (args[0] === 'workspace' && args[1] === 'create') console.log(JSON.stringify({result:{workspace:{workspace_id:'w9'},root_pane:{pane_id:'w9:p1'}}}));
if (args[1] === 'split') console.log(JSON.stringify({result:{pane:{pane_id:'w9:p2'}}}));
if (args[0] === 'plugin' && args[1] === 'list') console.log(JSON.stringify({result:{plugins:[]}}));
`, { mode: 0o755 });
  for (const tool of ['codex', 'nvim']) symlinkSync(fake, join(directory, tool));
  const env = { ...process.env, PATH: `${directory}:${process.env.PATH}`, WORKSPACE_TEST_LOG: log };
  const launcher = fileURLToPath(new URL('../scripts/herdr-workspace.mjs', import.meta.url));
  const output = execFileSync(process.execPath, [launcher, directory], { env, encoding: 'utf8' });
  assert.match(output, /Opened w9: codex/);
  execFileSync(process.execPath, [launcher, '--install-reviewr'], { env });
  const calls = readFileSync(log, 'utf8').trim().split('\n').map(line => JSON.parse(line));
  assert(calls.some(args => args[1] === 'run' && args[3] === 'codex'));
  assert.deepEqual(calls.at(-1), ['plugin', 'install', 'persiyanov/herdr-reviewr', '--ref', 'c9a187ff2e701d1619be2ed22d101a6225916cd6', '--yes']);
});
