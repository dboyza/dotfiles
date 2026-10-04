#!/usr/bin/env node
// Mutable applications live outside the Nix store; configuration stays in Git.
import { spawn, spawnSync } from 'node:child_process';
import { createHash, randomUUID } from 'node:crypto';
import * as fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const inventory = JSON.parse(fs.readFileSync(new URL('./managed-tools.json', import.meta.url), 'utf8'));
const repositories = Object.fromEntries(Object.entries(inventory)
  .filter(([, tool]) => tool.github).map(([name, tool]) => [name, tool.github]));
const managedTools = new Set(Object.keys(inventory));
const metadataTimeoutMs = 5000;
const downloadTimeoutMs = 90000;
const commandTimeoutMs = 180000;
const versionCheckTimeoutMs = 30000;
const unpublishedLockGraceMs = 30000;
const firstInstallWaitMs = 190000;
const lockRetryMs = 100;
const stableVersion = /^\d+\.\d+\.\d+$/;
const claudeDownloads = 'https://downloads.claude.ai/claude-code-releases';
const pause = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));

export function dataRoot() {
  const base = process.platform === 'win32'
    ? process.env.LOCALAPPDATA || path.join(os.homedir(), 'AppData', 'Local')
    : process.env.XDG_DATA_HOME || path.join(os.homedir(), '.local', 'share');
  return path.join(base, 'dotfiles', 'tools');
}

function readState(directory) {
  try {
    return JSON.parse(fs.readFileSync(path.join(directory, 'current.json'), 'utf8'));
  } catch (error) {
    if (error.code === 'ENOENT') return null;
    throw error;
  }
}

function publish(directory, state) {
  const temporary = path.join(directory, `current-${randomUUID()}.json`);
  fs.writeFileSync(temporary, JSON.stringify(state, null, 2) + '\n');
  fs.renameSync(temporary, path.join(directory, 'current.json'));
}

function command(directory, release) {
  const executable = path.join(directory, release.directory, release.executable);
  return release.node ? [process.execPath, executable] : [executable];
}

async function request(url, milliseconds = metadataTimeoutMs) {
  const response = await fetch(url, {
    signal: AbortSignal.timeout(milliseconds),
    headers: { 'User-Agent': 'dotfiles-tool-updater', Accept: 'application/json' },
  });
  if (!response.ok) throw new Error(`HTTP ${response.status} from ${new URL(url).hostname}`);
  return response;
}

export function standaloneAsset(tool, { platform, arch, musl = false }) {
  if (!['darwin', 'linux', 'win32'].includes(platform) || !['x64', 'arm64'].includes(arch)) {
    throw new Error(`${tool} does not support this platform`);
  }
  if (tool === 'codex') {
    const cpu = { x64: 'x86_64', arm64: 'aarch64' }[arch];
    const osName = { darwin: 'apple-darwin', linux: 'unknown-linux-musl', win32: 'pc-windows-msvc' }[platform];
    return `codex-package-${cpu}-${osName}.tar.gz`;
  }
  if (tool === 'pi' && platform === 'linux' && musl) {
    throw new Error('Pi standalone releases require glibc on Linux');
  }
  const osName = platform === 'win32' ? 'windows' : platform;
  // Baseline x64 builds also run on CPUs without AVX2.
  const baseline = tool === 'opencode' && arch === 'x64' ? '-baseline' : '';
  const libc = tool === 'opencode' && platform === 'linux' && musl ? '-musl' : '';
  const extension = platform === 'win32' || (tool === 'opencode' && platform === 'darwin') ? 'zip' : 'tar.gz';
  return `${tool}-${osName}-${arch}${baseline}${libc}.${extension}`;
}

export async function latestRelease(tool, {
  platform = process.platform, arch = process.arch, musl,
} = {}) {
  musl ??= platform === 'linux' && !process.report.getReport().header.glibcVersionRuntime;
  if (Object.hasOwn(repositories, tool)) {
    const artifact = standaloneAsset(tool, { platform, arch, musl });
    const repository = repositories[tool];
    const metadata = await (await request(`https://api.github.com/repos/${repository}/releases/latest`)).json();
    const prefix = tool === 'codex' ? 'rust-v' : 'v';
    const tag = metadata.tag_name || '';
    const version = tag.slice(prefix.length);
    if (!tag.startsWith(prefix) || !stableVersion.test(version) || metadata.draft || metadata.prerelease) {
      throw new Error(`${tool} did not return a stable release`);
    }
    const asset = metadata.assets?.find(entry => entry.name === artifact);
    const url = `https://github.com/${repository}/releases/download/${tag}/${artifact}`;
    if (asset?.browser_download_url !== url || !/^sha256:[a-f0-9]{64}$/i.test(asset?.digest || '')) {
      throw new Error(`${tool} release is missing the expected archive or SHA-256 digest`);
    }
    return { version, artifact, url, sha256: asset.digest.slice(7), platform, arch };
  }
  if (tool === 'claude') {
    if (!['darwin', 'linux', 'win32'].includes(platform) || !['x64', 'arm64'].includes(arch)) {
      throw new Error('Claude Code does not support this platform');
    }
    const target = `${platform}-${arch}${platform === 'linux' && musl ? '-musl' : ''}`;
    const version = (await (await request(`${claudeDownloads}/latest`)).text()).trim();
    if (!stableVersion.test(version)) throw new Error('Claude Code did not return a stable release');
    const manifest = await (await request(`${claudeDownloads}/${version}/manifest.json`)).json();
    const sha256 = manifest.platforms?.[target]?.checksum;
    if (manifest.version !== version || !/^[a-f0-9]{64}$/i.test(sha256 || '')) {
      throw new Error('Claude Code manifest is missing the release or platform checksum');
    }
    const executable = platform === 'win32' ? 'claude.exe' : 'claude';
    return { version, url: `${claudeDownloads}/${version}/${target}/${executable}`, sha256 };
  }
  if (tool !== 'herdr') throw new Error(`Unknown managed tool: ${tool}`);
  const osName = { darwin: 'macos', linux: 'linux', win32: 'windows' }[platform];
  const architecture = platform === 'win32' ? 'x86_64' : { x64: 'x86_64', arm64: 'aarch64' }[arch];
  if (!osName || !architecture) throw new Error('Herdr does not support this platform');
  const manifest = await (await request('https://herdr.dev/latest.json')).json();
  const target = `${osName}-${architecture}`;
  const url = manifest.assets?.[target];
  const sha256 = manifest.sha256?.[target];
  if (!stableVersion.test(manifest.version) || !/^[a-f0-9]{64}$/i.test(sha256 || '')) {
    throw new Error('Herdr manifest is missing a stable version or checksum');
  }
  if (!url?.startsWith(`https://github.com/herdrdev/herdr/releases/download/v${manifest.version}/`)) {
    throw new Error('Herdr manifest contains an unexpected download URL');
  }
  return { version: manifest.version, url, sha256 };
}

function run(executable, args, options = {}) {
  const result = spawnSync(executable, args, {
    encoding: 'utf8', timeout: commandTimeoutMs, maxBuffer: 8 * 1024 * 1024,
    ...options,
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`${path.basename(executable)} failed: ${(result.stderr || result.stdout || `exit ${result.status}`).trim().slice(-2000)}`);
  }
  return result.stdout;
}

function extractArchive(archive, directory) {
  // macOS and Windows provide bsdtar (including zip support); Linux releases
  // use tar.gz archives, supported by GNU tar without another dependency.
  const tar = process.platform === 'win32' ? 'tar.exe' : 'tar';
  const entries = run(tar, ['-tf', archive]).trim().split(/\r?\n/);
  if (entries.some(entry => /(^[/\\]|:|(^|[/\\])\.\.([/\\]|$)|[\x00-\x1f])/.test(entry))) {
    throw new Error('Release archive contains an unsafe path');
  }
  const listing = run(tar, ['-tvf', archive]).trim().split(/\r?\n/);
  // Reject links and special files before extraction, including links that
  // could make a later, otherwise safe archive member escape the stage.
  if (listing.length !== entries.length || listing.some(entry => !/^[-d]/.test(entry))) {
    throw new Error('Release archive contains a link or special file');
  }
  run(tar, ['-xf', archive, '-C', directory]);
  fs.unlinkSync(archive);
  return entries.map(entry => entry.replace(/^\.\//, ''));
}

function requireFile(directory, relative) {
  if (!fs.existsSync(path.join(directory, relative)) || !fs.statSync(path.join(directory, relative)).isFile()) {
    throw new Error(`Release archive is missing ${relative}`);
  }
}

export async function installRelease(tool, release, directory) {
  const bytes = Buffer.from(await (await request(release.url, downloadTimeoutMs)).arrayBuffer());
  if (createHash('sha256').update(bytes).digest('hex') !== release.sha256.toLowerCase()) {
    throw new Error(`${tool} download checksum mismatch`);
  }
  const platform = release.platform || process.platform;
  const suffix = platform === 'win32' ? '.exe' : '';
  let executable = `${tool}${suffix}`;
  if (release.artifact || (tool === 'herdr' && platform === 'win32')) {
    const archive = path.join(directory, 'release.archive');
    fs.writeFileSync(archive, bytes);
    const entries = extractArchive(archive, directory);
    if (tool === 'codex') {
      executable = `bin/codex${suffix}`;
      const metadata = JSON.parse(fs.readFileSync(path.join(directory, 'codex-package.json'), 'utf8'));
      const target = release.artifact.slice('codex-package-'.length, -'.tar.gz'.length);
      if (metadata.layoutVersion !== 1 || metadata.version !== release.version || metadata.target !== target ||
          metadata.variant !== 'codex' || metadata.entrypoint !== executable ||
          metadata.pathDir !== 'codex-path' || metadata.resourcesDir !== 'codex-resources') {
        throw new Error('Codex package manifest does not match the release');
      }
      const companions = [`bin/codex-code-mode-host${suffix}`, `codex-path/rg${suffix}`];
      if (platform === 'linux') companions.push('codex-resources/bwrap');
      if (platform === 'win32') companions.push('codex-resources/codex-command-runner.exe', 'codex-resources/codex-windows-sandbox-setup.exe');
      for (const companion of companions) requireFile(directory, companion);
    } else if (tool === 'pi') {
      const base = platform === 'win32' ? '' : 'pi/';
      executable = `${base}pi${suffix}`;
      for (const companion of ['package.json', 'photon_rs_bg.wasm', 'theme/dark.json', 'theme/light.json', 'export-html/template.html']) {
        requireFile(directory, base + companion);
      }
      const metadata = JSON.parse(fs.readFileSync(path.join(directory, base, 'package.json'), 'utf8'));
      if (metadata.version !== release.version) throw new Error('Pi package version does not match the release');
      const nativeDirectory = `${base}native/${platform}/prebuilds/${platform}-${release.arch}/`;
      if (!entries.some(entry => entry.startsWith(nativeDirectory) && entry.endsWith('.node'))) {
        throw new Error('Pi archive is missing its native platform helper');
      }
    } else if (tool === 'herdr') {
      executable = entries.find(entry => /(^|\/)herdr\.exe$/.test(entry));
      if (!executable) throw new Error('Herdr archive has no executable');
      for (const companion of ['conpty.dll', 'x64/OpenConsole.exe', 'arm64/OpenConsole.exe', 'herdr-conpty.json']) {
        requireFile(directory, path.join(path.dirname(executable), 'conpty', companion));
      }
    }
    requireFile(directory, executable);
  } else {
    fs.writeFileSync(path.join(directory, executable), bytes, { mode: 0o755 });
  }
  return { executable, node: false };
}

function toolEnvironment(tool) {
  return {
    ...process.env,
    // The launcher owns updates and version selection, including bypass mode.
    ...(tool === 'claude' ? { DISABLE_UPDATES: '1', DISABLE_AUTOUPDATER: '1' } : {}),
    ...(tool === 'opencode' ? { OPENCODE_DISABLE_AUTOUPDATE: 'true' } : {}),
    ...(tool === 'pi' ? { PI_SKIP_VERSION_CHECK: '1' } : {}),
  };
}

function alive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try { process.kill(pid, 0); return true; } catch (error) { return error.code !== 'ESRCH'; }
}

function acquireLock(directory) {
  const lock = path.join(directory, 'update.lock');
  try {
    // Exclusive file creation publishes the lock before its PID is written.
    const fd = fs.openSync(lock, 'wx', 0o600);
    fs.writeFileSync(fd, JSON.stringify({ pid: process.pid }));
    fs.closeSync(fd);
    return () => fs.unlinkSync(lock);
  } catch (error) {
    if (error.code !== 'EEXIST') throw error;
    // Serialize stale-lock reclamation so two launchers cannot remove a newly
    // acquired lock after both observed the same dead previous owner.
    const reaper = path.join(directory, 'reclaim.lock');
    try { fs.mkdirSync(reaper); } catch (reaperError) {
      if (reaperError.code === 'EEXIST') return null;
      throw reaperError;
    }
    try {
      try {
        const owner = JSON.parse(fs.readFileSync(lock, 'utf8'));
        if (!alive(owner.pid)) fs.unlinkSync(lock);
      } catch (readError) {
        // An empty lock can mean a process is still publishing its PID.
        if (readError instanceof SyntaxError) {
          if (Date.now() - fs.statSync(lock).mtimeMs > unpublishedLockGraceMs) fs.unlinkSync(lock);
        } else if (readError.code !== 'ENOENT') throw readError;
      }
    } finally {
      fs.rmdirSync(reaper);
    }
    return null;
  }
}

function verifyInstallation(tool, directory, installed) {
  const [executable, ...args] = command(directory, installed);
  const version = run(executable, [...args, '--version'], { timeout: versionCheckTimeoutMs, env: toolEnvironment(tool) });
  const escapedVersion = installed.version.replaceAll('.', '\\.');
  if (!new RegExp(`(^|[^\\d.])${escapedVersion}([^\\d.]|$)`).test(version)) {
    throw new Error('New executable failed its version check');
  }
}

export async function ensureInstallation(tool, {
  root = dataRoot(), update = process.env.DOTFILES_TOOL_UPDATE !== '0',
  latest = latestRelease, install = installRelease,
  log = message => console.error(`[${tool}] ${message}`), waitMilliseconds = firstInstallWaitMs,
} = {}) {
  if (!managedTools.has(tool)) throw new Error(`Unknown managed tool: ${tool}`);
  const directory = path.join(root, tool);
  fs.mkdirSync(directory, { recursive: true });
  let state = readState(directory);
  if (!update) {
    if (!state) throw new Error(`${tool} has not been installed; launch once with updates enabled`);
    return { directory, release: state.current };
  }

  // Observe the current installation, then serialize any mutation.
  let unlock;
  const deadline = Date.now() + waitMilliseconds;
  while (!(unlock = acquireLock(directory))) {
    state = readState(directory);
    if (state) return { directory, release: state.current };
    if (Date.now() >= deadline) throw new Error('Timed out waiting for the first installation');
    await pause(lockRetryMs);
  }
  let staging;
  try {
    state = readState(directory);
    const release = await latest(tool);
    // Version alone is insufficient: an unchanged version may need a bundle migration.
    const needsReplacement = !state || state.current.version !== release.version
      || state.current.artifact !== release.artifact;
    if (needsReplacement) {
      log(`Installing ${release.version}…`);
      const name = `${release.version}-${process.platform}-${process.arch}-${randomUUID()}`;
      staging = path.join(directory, name);
      fs.mkdirSync(staging);
      const entry = await install(tool, release, staging);
      const installed = { version: release.version, artifact: release.artifact, directory: name, ...entry };
      verifyInstallation(tool, directory, installed);
      // Publish only after the complete bundle passes its executable check.
      publish(directory, { current: installed, previous: state?.current || null });
      staging = null;
      state = readState(directory);
    }
  } catch (error) {
    if (!state) throw error;
    log(`Update unavailable (${error.message}); using ${state.current.version}.`);
  } finally {
    if (staging) fs.rmSync(staging, { recursive: true, force: true });
    unlock();
  }
  return { directory, release: state.current };
}

export async function main(tool, args = []) {
  try {
    const updateOnly = tool === '--update-only';
    if (updateOnly) [tool, ...args] = args;
    const { directory, release } = await ensureInstallation(tool);
    if (updateOnly) return;
    const [executable, ...prefix] = command(directory, release);
    const child = spawn(executable, [...prefix, ...args], {
      stdio: 'inherit',
      env: toolEnvironment(tool),
    });
    const signals = ['SIGINT', 'SIGTERM', 'SIGHUP'];
    const handlers = signals.map(signal => {
      const handler = () => child.kill(signal);
      process.on(signal, handler);
      return handler;
    });
    child.on('error', error => { console.error(error.message); process.exitCode = 1; });
    child.on('exit', (code, signal) => {
      signals.forEach((name, index) => process.removeListener(name, handlers[index]));
      process.exitCode = code ?? (128 + (os.constants.signals[signal] || 1));
    });
  } catch (error) {
    console.error(`[${tool || 'dotfiles-tool'}] ${error.message}`);
    process.exitCode = 1;
  }
}

if (process.argv[1] && pathToFileURL(fs.realpathSync(process.argv[1])).href === import.meta.url) {
  await main(process.argv[2], process.argv.slice(3));
}
