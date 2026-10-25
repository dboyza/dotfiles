// Exercise Reviewr installation and removal of the retired new-space layout plugin.
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { installPlugins } from '../scripts/install-herdr-plugins.mjs';

const installer = fileURLToPath(new URL('../scripts/install-herdr-plugins.mjs', import.meta.url));

// Section: Isolated Herdr executable that records every command
function fakeHerdr(t, plugins, failure) {
  const directory = realpathSync(mkdtempSync(join(tmpdir(), 'herdr plugins ')));
  t.after(() => rmSync(directory, { recursive: true }));
  const log = join(directory, 'calls.jsonl');
  writeFileSync(join(directory, 'herdr'), `#!/usr/bin/env node
import { appendFileSync } from 'node:fs';
const args = process.argv.slice(2);
appendFileSync(${JSON.stringify(log)}, JSON.stringify(args) + '\\n');
if (args[1] === 'list') console.log(JSON.stringify({result:{plugins:${JSON.stringify(plugins)}}}));
if (args[1] === ${JSON.stringify(failure)}) {
  console.error(JSON.stringify({error:{code:'failed',message:'fixture failure'}}));
  process.exit(1);
}
`, { mode: 0o755 });
  const env = { ...process.env, PATH: `${directory}:${process.env.PATH}`, HERDR_BIN_PATH: '' };
  const run = () => spawnSync(process.execPath, [installer], { env, encoding: 'utf8' });
  const calls = () => readFileSync(log, 'utf8').trim().split('\n').map(line => JSON.parse(line));
  return { run, calls };
}

test('existing Reviewr is preserved and new spaces keep the default layout', () => {
  const calls = [];
  installPlugins(args => { calls.push(args); return { plugins: [{ plugin_id: 'persiyanov.reviewr' }] }; });
  assert.deepEqual(calls, [['plugin', 'list', '--json']]);
});

test('CLI installs missing Reviewr from the pinned source and unlinks the retired layout', { skip: process.platform === 'win32' }, t => {
  const { run, calls } = fakeHerdr(t, [{ plugin_id: 'dotfiles.workspace' }]);
  assert.equal(run().status, 0);
  assert.deepEqual(calls().slice(1), [
    ['plugin', 'install', 'persiyanov/herdr-reviewr', '--ref', 'c9a187ff2e701d1619be2ed22d101a6225916cd6', '--yes'],
    ['plugin', 'unlink', 'dotfiles.workspace'],
  ]);
});

test('CLI reports Herdr failures with a nonzero exit', { skip: process.platform === 'win32' }, t => {
  const { run } = fakeHerdr(t, [{ plugin_id: 'persiyanov.reviewr' }, { plugin_id: 'dotfiles.workspace' }], 'unlink');
  const result = run();
  assert.equal(result.status, 1);
  assert.match(result.stderr, /install-herdr-plugins: fixture failure/);
});
