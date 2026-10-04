// Check native release selection, complete bundles, and archive extraction boundaries.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import * as fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { ensureInstallation, installRelease, latestRelease, standaloneAsset } from '../scripts/dotfiles-tool.mjs';

const repositories = { codex: 'openai/codex', pi: 'earendil-works/pi', opencode: 'anomalyco/opencode' };
const checksum = bytes => createHash('sha256').update(bytes).digest('hex');
const log = () => {};

// Section: Disposable releases and archives
function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'dotfiles-native-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  return root;
}

function metadata(tool, artifact, bytes, version = '1.0.0') {
  const tag = `${tool === 'codex' ? 'rust-v' : 'v'}${version}`;
  const url = `https://github.com/${repositories[tool]}/releases/download/${tag}/${artifact}`;
  return {
    tag_name: tag, draft: false, prerelease: false,
    assets: [{ name: artifact, browser_download_url: url, digest: `sha256:${checksum(bytes)}` }],
  };
}

function nativeFiles(tool, platform, arch, version = '1.0.0') {
  const suffix = platform === 'win32' ? '.exe' : '';
  const binary = `#!/bin/sh\nif [ "$1" = --version ]; then echo '${version}'; else printf 'native:%s\\n' "$1"; fi\n`;
  if (tool === 'codex') {
    const artifact = standaloneAsset(tool, { platform, arch });
    return {
      [`bin/codex${suffix}`]: binary,
      [`bin/codex-code-mode-host${suffix}`]: binary,
      [`codex-path/rg${suffix}`]: binary,
      'codex-package.json': JSON.stringify({
        layoutVersion: 1, version, target: artifact.slice('codex-package-'.length, -'.tar.gz'.length),
        variant: 'codex', entrypoint: `bin/codex${suffix}`, pathDir: 'codex-path', resourcesDir: 'codex-resources',
      }),
      ...(platform === 'linux' ? { 'codex-resources/bwrap': binary } : {}),
      ...(platform === 'win32' ? {
        'codex-resources/codex-command-runner.exe': binary,
        'codex-resources/codex-windows-sandbox-setup.exe': binary,
      } : {}),
    };
  }
  if (tool === 'pi') {
    const base = platform === 'win32' ? '' : 'pi/';
    return Object.fromEntries(Object.entries({
      [`pi${suffix}`]: binary, 'package.json': JSON.stringify({ version }),
      'photon_rs_bg.wasm': 'wasm', 'theme/dark.json': '{}', 'theme/light.json': '{}',
      'export-html/template.html': '<html></html>',
      [`native/${platform}/prebuilds/${platform}-${arch}/${platform}-platform.node`]: 'native helper',
    }).map(([name, contents]) => [base + name, contents]));
  }
  return { [`opencode${suffix}`]: binary };
}

function archive(t, files) {
  const root = fixture(t);
  const source = path.join(root, 'source');
  fs.mkdirSync(source);
  for (const [name, contents] of Object.entries(files)) {
    const target = path.join(source, name);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, contents, { mode: 0o755 });
  }
  const target = path.join(root, 'fixture.tar.gz');
  const result = spawnSync(process.platform === 'win32' ? 'tar.exe' : 'tar', ['-czf', target, '-C', source, '.'], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  return fs.readFileSync(target);
}

// Minimal USTAR records let us exercise unsafe paths and links without asking
// the fixture writer or host tar to normalize the malicious entry first.
function unsafeArchive(name, type = '0', link = '') {
  const header = Buffer.alloc(512);
  header.write(name, 0, 100);
  header.write('0000755\0', 100);
  header.write('0000000\0', 108);
  header.write('0000000\0', 116);
  header.write('00000000000\0', 124);
  header.write('00000000000\0', 136);
  header.fill(' ', 148, 156);
  header.write(type, 156);
  header.write(link, 157, 100);
  header.write('ustar\0', 257);
  header.write('00', 263);
  header.write([...header].reduce((sum, byte) => sum + byte, 0).toString(8).padStart(6, '0') + '\0 ', 148);
  return Buffer.concat([header, Buffer.alloc(1024)]);
}

// Section: Platform assets and complete runtime bundles
test('standalone assets cover supported OS and CPU combinations with portable x64 builds', () => {
  const cases = [
    ['darwin', 'arm64', ['codex-package-aarch64-apple-darwin.tar.gz', 'pi-darwin-arm64.tar.gz', 'opencode-darwin-arm64.zip']],
    ['darwin', 'x64', ['codex-package-x86_64-apple-darwin.tar.gz', 'pi-darwin-x64.tar.gz', 'opencode-darwin-x64-baseline.zip']],
    ['linux', 'arm64', ['codex-package-aarch64-unknown-linux-musl.tar.gz', 'pi-linux-arm64.tar.gz', 'opencode-linux-arm64.tar.gz']],
    ['linux', 'x64', ['codex-package-x86_64-unknown-linux-musl.tar.gz', 'pi-linux-x64.tar.gz', 'opencode-linux-x64-baseline.tar.gz']],
    ['win32', 'arm64', ['codex-package-aarch64-pc-windows-msvc.tar.gz', 'pi-windows-arm64.zip', 'opencode-windows-arm64.zip']],
    ['win32', 'x64', ['codex-package-x86_64-pc-windows-msvc.tar.gz', 'pi-windows-x64.zip', 'opencode-windows-x64-baseline.zip']],
  ];
  for (const [platform, arch, names] of cases) {
    ['codex', 'pi', 'opencode'].forEach((tool, index) => assert.equal(standaloneAsset(tool, { platform, arch }), names[index]));
  }
  assert.equal(standaloneAsset('opencode', { platform: 'linux', arch: 'x64', musl: true }), 'opencode-linux-x64-baseline-musl.tar.gz');
  assert.throws(() => standaloneAsset('pi', { platform: 'linux', arch: 'arm64', musl: true }), /glibc/);
  assert.throws(() => standaloneAsset('codex', { platform: 'linux', arch: 'ia32' }), /support/);
});

for (const tool of Object.keys(repositories)) {
  test(`${tool} resolves an official stable archive and rejects unverified releases`, async t => {
    const options = { platform: 'darwin', arch: 'arm64' };
    const artifact = standaloneAsset(tool, options);
    const good = metadata(tool, artifact, Buffer.from('binary'));
    t.mock.method(globalThis, 'fetch', async url => {
      assert.equal(url, `https://api.github.com/repos/${repositories[tool]}/releases/latest`);
      return Response.json(good);
    });
    const release = await latestRelease(tool, options);
    assert.equal(release.version, '1.0.0');
    assert.equal(release.artifact, artifact);
    assert.equal(release.sha256, good.assets[0].digest.slice(7));
    for (const bad of [
      { ...good, tag_name: 'v../bad' }, { ...good, prerelease: true }, { ...good, draft: true },
      { ...good, assets: [] },
      { ...good, assets: [{ ...good.assets[0], digest: null }] },
      { ...good, assets: [{ ...good.assets[0], browser_download_url: 'https://example.invalid/file' }] },
    ]) {
      t.mock.method(globalThis, 'fetch', async () => Response.json(bad));
      await assert.rejects(latestRelease(tool, options), /stable release|SHA-256 digest/);
    }
  });

  test(`${tool} preserves complete standalone archives on macOS, Linux, and Windows`, async t => {
    for (const platform of ['darwin', 'linux', 'win32']) {
      const arch = 'arm64';
      const files = nativeFiles(tool, platform, arch);
      const bytes = archive(t, files);
      t.mock.method(globalThis, 'fetch', async () => new Response(bytes));
      const directory = fixture(t);
      const release = { version: '1.0.0', platform, arch, artifact: standaloneAsset(tool, { platform, arch }), url: 'https://example.invalid/archive', sha256: checksum(bytes) };
      const installed = await installRelease(tool, release, directory);
      assert.equal(installed.node, false);
      assert.ok(files[installed.executable]);
      for (const [name, contents] of Object.entries(files)) {
        assert.equal(fs.readFileSync(path.join(directory, name), 'utf8'), contents);
      }
      assert.ok(!fs.existsSync(path.join(directory, 'release.archive')));
    }
  });

  test(`${tool} migrates an npm installation at the same version and preserves offline fallback`, async t => {
    const root = fixture(t);
    const latest = async () => ({ version: '1.0.0' });
    const install = async (_tool, _release, directory) => {
      fs.writeFileSync(path.join(directory, 'old.mjs'), 'console.log("1.0.0")');
      return { executable: 'old.mjs', node: true };
    };
    const old = await ensureInstallation(tool, { root, latest, install, log });
    const nativeLatest = async () => ({ version: '1.0.0', artifact: 'native-release.tar.gz' });
    const failed = await ensureInstallation(tool, { root, latest: nativeLatest, log, install: async () => { throw new Error('offline'); } });
    assert.deepEqual(failed, old);
    const migrated = await ensureInstallation(tool, { root, latest: nativeLatest, install, log });
    assert.notEqual(migrated.release.directory, old.release.directory);
    assert.equal(migrated.release.artifact, 'native-release.tar.gz');
    const state = JSON.parse(fs.readFileSync(path.join(root, tool, 'current.json')));
    assert.deepEqual(state.previous, old.release);
    assert.deepEqual(await ensureInstallation(tool, { root, latest: nativeLatest, install: async () => { throw new Error('must not reinstall'); }, log }), migrated);
  });
}

// Section: Unsafe or incomplete archives
test('native archives reject traversal, absolute paths, symlinks, hardlinks, and special files before extraction', async t => {
  for (const [name, type, link] of [
    ['../outside', '0', ''], ['/absolute', '0', ''], ['C:\\outside', '0', ''],
    ['opencode', '2', '../outside'], ['opencode', '1', '../outside'], ['device', '3', ''],
  ]) {
    const bytes = unsafeArchive(name, type, link);
    t.mock.method(globalThis, 'fetch', async () => new Response(bytes));
    await assert.rejects(installRelease('opencode', {
      artifact: 'archive.tar.gz', sha256: checksum(bytes), url: 'https://example.invalid/archive',
    }, fixture(t)), /unsafe path|link or special file/);
  }
});

test('incomplete Codex and Pi archives are never accepted', async t => {
  for (const [tool, missing] of [['codex', 'bin/codex-code-mode-host'], ['pi', 'pi/photon_rs_bg.wasm'], ['pi', 'pi/native/darwin/prebuilds/darwin-arm64/darwin-platform.node']]) {
    const files = nativeFiles(tool, 'darwin', 'arm64');
    delete files[missing];
    const bytes = archive(t, files);
    t.mock.method(globalThis, 'fetch', async () => new Response(bytes));
    await assert.rejects(installRelease(tool, {
      version: '1.0.0', platform: 'darwin', arch: 'arm64',
      artifact: standaloneAsset(tool, { platform: 'darwin', arch: 'arm64' }),
      sha256: checksum(bytes), url: 'https://example.invalid/archive',
    }, fixture(t)), /missing/);
  }
});

// Section: CLI download and launch workflow
test('real launcher downloads a standalone archive and runs it without npm', {
  skip: process.platform === 'win32' && 'Unix executable fixture; Windows layout is tested separately',
}, async t => {
  const base = fixture(t);
  const options = { platform: process.platform, arch: process.arch };
  const artifact = standaloneAsset('opencode', options);
  const bytes = archive(t, nativeFiles('opencode', options.platform, options.arch));
  const mock = path.join(base, 'release-source.mjs');
  fs.writeFileSync(mock, `
    globalThis.fetch = async url => url.includes('api.github.com')
      ? Response.json(${JSON.stringify(metadata('opencode', artifact, bytes))})
      : new Response(Buffer.from('${bytes.toString('base64')}', 'base64'));
  `);
  const bin = path.join(base, 'bin');
  fs.mkdirSync(bin);
  fs.writeFileSync(path.join(bin, 'npm'), '#!/bin/sh\nexit 99\n', { mode: 0o755 });
  const result = spawnSync(process.execPath, ['--import', mock, path.resolve('scripts/opencode'), 'space here'], {
    cwd: base, encoding: 'utf8',
    env: { ...process.env, PATH: `${bin}${path.delimiter}${process.env.PATH}`, DOTFILES_TOOL_UPDATE: '1', XDG_DATA_HOME: base, LOCALAPPDATA: base },
  });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.trim(), 'native:space here');
  const state = JSON.parse(fs.readFileSync(path.join(base, 'dotfiles/tools/opencode/current.json')));
  assert.equal(state.current.node, false);
  assert.equal(state.current.artifact, artifact);
});
