import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import * as fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { ensureInstallation, latestRelease, installRelease } from '../scripts/dotfiles-tool.mjs';

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

for (const tool of ['codex', 'claude', 'pi', 'opencode', 'herdr']) test(`${tool} launcher preserves arguments, working directory, environment and exit status`, async t => {
  const base = fixture(t);
  const root = path.join(base, 'dotfiles', 'tools');
  await ensureInstallation(tool, { root, latest, install, log });
  const launcher = path.resolve(`scripts/${tool}`);
  const args = ['space here', '日本語', '"quoted"', '$HOME', 'a&b'];
  const result = spawnSync(process.execPath, [launcher, ...args], {
    cwd: base, encoding: 'utf8',
    env: { ...process.env, DOTFILES_TOOL_UPDATE: '0', XDG_DATA_HOME: base, LOCALAPPDATA: base, TEST_MARKER: 'preserved' },
  });
  assert.equal(result.status, 7, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), { args, cwd: fs.realpathSync(base), marker: 'preserved' });
});

test('Claude native release selection covers macOS, Linux, WSL, musl, and Windows architectures', async t => {
  const checksum = 'a'.repeat(64);
  for (const platform of ['darwin', 'linux', 'win32']) {
    for (const arch of ['x64', 'arm64']) {
      for (const musl of platform === 'linux' ? [false, true] : [false]) {
        const target = `${platform}-${arch}${musl ? '-musl' : ''}`;
        const requests = [];
        t.mock.method(globalThis, 'fetch', async url => {
          requests.push(url);
          return url.endsWith('/latest') ? new Response('2.1.286\n') : Response.json({
            version: '2.1.286', platforms: { [target]: { checksum } },
          });
        });
        const release = await latestRelease('claude', { platform, arch, musl });
        assert.deepEqual(requests, [
          'https://downloads.claude.ai/claude-code-releases/latest',
          'https://downloads.claude.ai/claude-code-releases/2.1.286/manifest.json',
        ]);
        assert.equal(release.url, `https://downloads.claude.ai/claude-code-releases/2.1.286/${target}/claude${platform === 'win32' ? '.exe' : ''}`);
        assert.equal(release.sha256, checksum);
        t.mock.restoreAll();
      }
    }
  }
});

test('Claude rejects malformed releases and incomplete or mismatched manifests', async t => {
  const options = { platform: 'darwin', arch: 'arm64' };
  for (const version of ['<html>unavailable</html>', '../other', '2.0.0-beta']) {
    t.mock.method(globalThis, 'fetch', async () => new Response(version));
    await assert.rejects(latestRelease('claude', options), /stable release/);
    t.mock.restoreAll();
  }
  for (const manifest of [
    { version: '2.0.0', platforms: {} },
    { version: '1.0.0', platforms: { 'darwin-arm64': { checksum: 'a'.repeat(64) } } },
    { version: '2.0.0', platforms: { 'darwin-arm64': { checksum: 'invalid' } } },
  ]) {
    t.mock.method(globalThis, 'fetch', async url => url.endsWith('/latest')
      ? new Response('2.0.0') : Response.json(manifest));
    await assert.rejects(latestRelease('claude', options), /platform checksum/);
    t.mock.restoreAll();
  }
  await assert.rejects(latestRelease('claude', { platform: 'freebsd', arch: 'x64' }), /support/);
});

test('native downloads are verified before writing an executable', async t => {
  const bytes = Buffer.from('native executable fixture');
  t.mock.method(globalThis, 'fetch', async () => new Response(bytes));
  const root = fixture(t);
  const release = { url: 'https://example.invalid/binary', sha256: '0'.repeat(64) };
  await assert.rejects(installRelease('claude', release, root), /checksum mismatch/);
  assert.deepEqual(fs.readdirSync(root), []);
  const installed = await installRelease('claude', {
    ...release, sha256: createHash('sha256').update(bytes).digest('hex'),
  }, root);
  assert.equal(installed.node, false);
  assert.deepEqual(fs.readFileSync(path.join(root, installed.executable)), bytes);
  if (process.platform !== 'win32') assert.ok(fs.statSync(path.join(root, installed.executable)).mode & 0o111);
});

test('Claude launch checks, installs, and starts the new release before accepting arguments', {
  skip: process.platform === 'win32' && 'Unix executable fixture; Windows selection is tested separately',
}, async t => {
  const base = fixture(t);
  const root = path.join(base, 'dotfiles', 'tools');
  await ensureInstallation('claude', { root, latest, install, log });
  const binary = '#!/bin/sh\nif [ "$1" = --version ]; then echo "2.0.0 (Claude Code)"; else printf "new:%s:%s:%s\\n" "$1" "$DISABLE_UPDATES" "$DISABLE_AUTOUPDATER"; fi\n';
  const checksum = createHash('sha256').update(binary).digest('hex');
  const mock = path.join(base, 'release-source.mjs');
  fs.writeFileSync(mock, `
    globalThis.fetch = async url => {
      if (url.endsWith('/latest')) return new Response('2.0.0');
      if (url.endsWith('/manifest.json')) return Response.json({
        version: '2.0.0', platforms: { '${process.platform}-${process.arch}': { checksum: '${checksum}' } },
      });
      return new Response(${JSON.stringify(binary)});
    };
  `);
  const result = spawnSync(process.execPath, ['--import', mock, path.resolve('scripts/claude'), 'space here'], {
    cwd: base, encoding: 'utf8',
    env: { ...process.env, DOTFILES_TOOL_UPDATE: '1', XDG_DATA_HOME: base, LOCALAPPDATA: base },
  });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.trim(), 'new:space here:1:1');
  const state = JSON.parse(fs.readFileSync(path.join(root, 'claude', 'current.json')));
  assert.equal(state.current.version, '2.0.0');
  assert.equal(state.previous.version, '1.0.0');
});
