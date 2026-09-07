#!/usr/bin/env node
// Mutable applications live outside the Nix store; configuration stays in Git.
import { spawn, spawnSync } from 'node:child_process';
import { createHash, randomUUID } from 'node:crypto';
import * as fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export const packages = {
  codex: '@openai/codex',
  pi: '@earendil-works/pi-coding-agent',
  opencode: 'opencode-ai',
  herdr: null,
};
const stableVersion = /^\d+\.\d+\.\d+$/;
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

async function request(url, milliseconds = 5000) {
  const response = await fetch(url, {
    signal: AbortSignal.timeout(milliseconds),
    headers: { 'User-Agent': 'dotfiles-tool-updater', Accept: 'application/json' },
  });
  if (!response.ok) throw new Error(`HTTP ${response.status} from ${new URL(url).hostname}`);
  return response;
}

export async function latestRelease(tool) {
  if (tool !== 'herdr') {
    const metadata = await (await request(`https://registry.npmjs.org/${packages[tool]}/latest`)).json();
    if (!stableVersion.test(metadata.version)) throw new Error('Registry did not return a stable release');
    return { version: metadata.version };
  }
  const platform = { darwin: 'macos', linux: 'linux', win32: 'windows' }[process.platform];
  const architecture = process.platform === 'win32' ? 'x86_64' : { x64: 'x86_64', arm64: 'aarch64' }[process.arch];
  if (!platform || !architecture) throw new Error('Herdr does not support this platform');
  const manifest = await (await request('https://herdr.dev/latest.json')).json();
  const target = `${platform}-${architecture}`;
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
    encoding: 'utf8', timeout: 180000, maxBuffer: 8 * 1024 * 1024,
    ...options,
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`${path.basename(executable)} failed: ${(result.stderr || result.stdout || `exit ${result.status}`).trim().slice(-2000)}`);
  }
  return result.stdout;
}

function npmCommand() {
  if (process.platform !== 'win32') return ['npm'];
  // Invoke npm's JS entry point directly, avoiding cmd.exe argument interpolation.
  const candidates = [
    path.join(path.dirname(process.execPath), 'node_modules', 'npm', 'bin', 'npm-cli.js'),
    ...(process.env.PATH || '').split(path.delimiter)
      .map(directory => path.join(directory, 'node_modules', 'npm', 'bin', 'npm-cli.js')),
  ];
  const cli = candidates.find(candidate => fs.existsSync(candidate));
  if (!cli) throw new Error('npm is missing; install Node.js 24 LTS with npm');
  return [process.execPath, cli];
}

export async function installRelease(tool, release, directory) {
  if (tool === 'herdr') {
    const bytes = Buffer.from(await (await request(release.url, 90000)).arrayBuffer());
    if (createHash('sha256').update(bytes).digest('hex') !== release.sha256.toLowerCase()) {
      throw new Error('Herdr download checksum mismatch');
    }
    if (process.platform === 'win32') {
      const archive = path.join(directory, 'herdr.zip');
      fs.writeFileSync(archive, bytes);
      const entries = run('tar.exe', ['-tf', archive]).trim().split(/\r?\n/);
      if (entries.some(entry => /(^[/\\]|^[a-z]:|(^|[/\\])\.\.([/\\]|$))/i.test(entry))) {
        throw new Error('Herdr archive contains an unsafe path');
      }
      run('tar.exe', ['-xf', archive, '-C', directory]);
      fs.unlinkSync(archive);
      // Keep the entire archive, including ConPTY DLLs, alongside the binary.
      const executable = entries.find(entry => /(^|\/)herdr\.exe$/.test(entry));
      if (!executable) throw new Error('Herdr archive has no executable');
      for (const companion of ['conpty.dll', 'x64/OpenConsole.exe', 'arm64/OpenConsole.exe', 'herdr-conpty.json']) {
        if (!fs.existsSync(path.join(directory, path.dirname(executable), 'conpty', companion))) {
          throw new Error(`Herdr archive is missing its ConPTY runtime: ${companion}`);
        }
      }
      return { executable, node: false };
    }
    fs.writeFileSync(path.join(directory, 'herdr'), bytes, { mode: 0o755 });
    return { executable: 'herdr', node: false };
  }

  fs.writeFileSync(path.join(directory, 'package.json'), JSON.stringify({ private: true }));
  const [npm, ...prefix] = npmCommand();
  run(npm, [...prefix, 'install', '--prefix', directory, '--save-exact', '--omit=dev',
    '--include=optional', '--no-audit', '--no-fund', '--no-package-lock',
    '--registry=https://registry.npmjs.org', '--fetch-retries=1', '--fetch-timeout=30000',
    // OpenCode's official postinstall selects its platform executable.
    ...(tool === 'opencode' ? [] : ['--ignore-scripts']),
    `${packages[tool]}@${release.version}`], { cwd: directory });
  const packageDirectory = path.join(directory, 'node_modules', packages[tool]);
  const metadata = JSON.parse(fs.readFileSync(path.join(packageDirectory, 'package.json'), 'utf8'));
  if (metadata.version !== release.version) throw new Error('Installed package version does not match release');
  const bin = typeof metadata.bin === 'string' ? metadata.bin : metadata.bin?.[tool];
  if (!bin) throw new Error(`Package does not export ${tool}`);
  const executable = path.resolve(packageDirectory, bin);
  if (!executable.startsWith(packageDirectory + path.sep)) throw new Error('Unexpected package executable path');
  const header = Buffer.alloc(256);
  const fd = fs.openSync(executable, 'r');
  fs.readSync(fd, header, 0, header.length, 0);
  fs.closeSync(fd);
  return {
    executable: path.relative(directory, executable),
    node: /\.[cm]?js$/.test(bin) || /^#![^\r\n]*\bnode\b/.test(header.toString('utf8')),
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
          if (Date.now() - fs.statSync(lock).mtimeMs > 30000) fs.unlinkSync(lock);
        } else if (readError.code !== 'ENOENT') throw readError;
      }
    } finally {
      fs.rmdirSync(reaper);
    }
    return null;
  }
}

export async function ensureInstallation(tool, {
  root = dataRoot(), update = process.env.DOTFILES_TOOL_UPDATE !== '0',
  latest = latestRelease, install = installRelease,
  log = message => console.error(`[${tool}] ${message}`), waitMilliseconds = 190000,
} = {}) {
  if (!Object.hasOwn(packages, tool)) throw new Error(`Unknown managed tool: ${tool}`);
  const directory = path.join(root, tool);
  fs.mkdirSync(directory, { recursive: true });
  let state = readState(directory);
  if (!update) {
    if (!state) throw new Error(`${tool} has not been installed; launch once with updates enabled`);
    return { directory, release: state.current };
  }

  let unlock;
  const deadline = Date.now() + waitMilliseconds;
  while (!(unlock = acquireLock(directory))) {
    state = readState(directory);
    if (state) return { directory, release: state.current };
    if (Date.now() >= deadline) throw new Error('Timed out waiting for the first installation');
    await pause(100);
  }
  let staging;
  try {
    state = readState(directory);
    const release = await latest(tool);
    if (!state || state.current.version !== release.version) {
      log(`Installing ${release.version}…`);
      const name = `${release.version}-${process.platform}-${process.arch}-${randomUUID()}`;
      staging = path.join(directory, name);
      fs.mkdirSync(staging);
      const entry = await install(tool, release, staging);
      const installed = { version: release.version, directory: name, ...entry };
      const [executable, ...args] = command(directory, installed);
      const version = run(executable, [...args, '--version'], { timeout: 30000 });
      const escapedVersion = release.version.replaceAll('.', '\\.');
      if (!new RegExp(`(^|[^\\d.])${escapedVersion}([^\\d.]|$)`).test(version)) {
        throw new Error('New executable failed its version check');
      }
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
      env: {
        ...process.env,
        ...(tool === 'opencode' ? { OPENCODE_DISABLE_AUTOUPDATE: 'true' } : {}),
        ...(tool === 'pi' ? { PI_SKIP_VERSION_CHECK: '1' } : {}),
      },
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
