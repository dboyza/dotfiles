import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import * as fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { ensureInstallation } from '../scripts/dotfiles-tool.mjs';

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'dotfiles-tools-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  return root;
}

const latest = async () => ({ version: '1.0.0' });
const log = () => {};
async function install(_tool, release, directory) {
  fs.writeFileSync(path.join(directory, 'cli.mjs'), `
    if (process.argv[2] === '--version') console.log(${JSON.stringify(release.version)});
    else {
      console.log(JSON.stringify({ args: process.argv.slice(2), cwd: process.cwd(), marker: process.env.TEST_MARKER }));
      process.exitCode = 7;
    }
  `);
  return { executable: 'cli.mjs', node: true };
}

test('first launch installs once; unchanged releases reuse the existing executable', async t => {
  const root = fixture(t);
  let installs = 0;
  const options = { root, latest, log, install: async (...args) => { installs++; return install(...args); } };
  const first = await ensureInstallation('codex', options);
  const second = await ensureInstallation('codex', options);
  assert.deepEqual(first, second);
  assert.equal(installs, 1);
  assert.equal(fs.existsSync(path.join(root, 'codex', 'update.lock')), false);
});

test('failed and offline updates preserve the working release; successful updates retain the previous directory', async t => {
  const root = fixture(t);
  const options = { root, latest, install, log };
  const first = await ensureInstallation('pi', options);
  const offline = await ensureInstallation('pi', { ...options, latest: async () => { throw new Error('offline'); } });
  assert.deepEqual(offline, first);
  const next = async () => ({ version: '2.0.0' });
  const failed = await ensureInstallation('pi', {
    ...options, latest: next,
    install: async (...args) => { await install(...args); throw new Error('interrupted download'); },
  });
  assert.deepEqual(failed, first);
  assert.equal(fs.readdirSync(first.directory).filter(name => name.startsWith('2.0.0-')).length, 0);
  const second = await ensureInstallation('pi', { ...options, latest: next });
  const state = JSON.parse(fs.readFileSync(path.join(first.directory, 'current.json')));
  assert.deepEqual(state.previous, first.release);
  assert.equal(second.release.version, '2.0.0');
  assert.ok(fs.existsSync(path.join(first.directory, first.release.directory, 'cli.mjs')));
});

test('a broken executable is never published', async t => {
  const root = fixture(t);
  await assert.rejects(ensureInstallation('opencode', {
    root, latest, log,
    install: async (tool, release, directory) => install(tool, { version: '0.0.0' }, directory),
  }), /version check/);
  assert.deepEqual(fs.readdirSync(path.join(root, 'opencode')), []);
});

test('simultaneous first launches serialize installation', async t => {
  const root = fixture(t);
  let installs = 0;
  const options = {
    root, log, latest,
    install: async (...args) => {
      installs++;
      await new Promise(resolve => setTimeout(resolve, 200));
      return install(...args);
    },
  };
  const results = await Promise.all([ensureInstallation('herdr', options), ensureInstallation('herdr', options)]);
  assert.deepEqual(results[0], results[1]);
  assert.equal(installs, 1);
});

test('busy update uses installed version, stale update lock recovers, and bypass does not check the network', async t => {
  const root = fixture(t);
  const options = { root, latest, install, log };
  const first = await ensureInstallation('codex', options);
  const lock = path.join(first.directory, 'update.lock');
  fs.writeFileSync(lock, JSON.stringify({ pid: process.pid }));
  const failIfCalled = async () => { throw new Error('must not contact network'); };
  assert.deepEqual(await ensureInstallation('codex', { ...options, latest: failIfCalled }), first);
  assert.deepEqual(await ensureInstallation('codex', { ...options, update: false, latest: failIfCalled }), first);
  fs.writeFileSync(lock, JSON.stringify({ pid: 2147483647 }));
  assert.deepEqual(await ensureInstallation('codex', options), first);
  assert.equal(fs.existsSync(lock), false);
  fs.writeFileSync(lock, '');
  const old = new Date(Date.now() - 60000);
  fs.utimesSync(lock, old, old);
  assert.deepEqual(await ensureInstallation('codex', options), first);
  assert.equal(fs.existsSync(lock), false);
});

test('first installation fails clearly offline and rejects unknown tool names', async t => {
  const root = fixture(t);
  await assert.rejects(ensureInstallation('pi', { root, update: false }), /has not been installed/);
  await assert.rejects(ensureInstallation('../other', { root }), /Unknown managed tool/);
  await assert.rejects(ensureInstallation('pi', {
    root, latest: async () => { throw new Error('offline'); }, log,
  }), /offline/);
});

test('real launcher preserves arguments, working directory, environment and exit status', async t => {
  const base = fixture(t);
  const root = path.join(base, 'dotfiles', 'tools');
  await ensureInstallation('codex', { root, latest, install, log });
  const launcher = path.resolve('scripts/codex');
  const args = ['space here', '日本語', '"quoted"', '$HOME', 'a&b'];
  const result = spawnSync(process.execPath, [launcher, ...args], {
    cwd: base, encoding: 'utf8',
    env: { ...process.env, DOTFILES_TOOL_UPDATE: '0', XDG_DATA_HOME: base, LOCALAPPDATA: base, TEST_MARKER: 'preserved' },
  });
  assert.equal(result.status, 7, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), { args, cwd: fs.realpathSync(base), marker: 'preserved' });
});
