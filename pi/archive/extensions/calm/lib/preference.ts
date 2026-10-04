// Pi Calm - atomically persist the on/off preference in Pi's runtime agent directory.
// The state file is never tracked or deployed; missing or unreadable state means off.

// Copyright (c) 2026 Kun Chen. MIT License - see the LICENSE file in this directory.

import { randomUUID } from "node:crypto";
import {
  mkdirSync,
  readFileSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import * as PiCodingAgent from "@earendil-works/pi-coding-agent";

export const CALM_PREFERENCE_FILE_NAME = "calm";

// Section: Runtime state location

// Prefer Pi's path resolution, falling back to its environment variable and default.
export function calmAgentDir(): string {
  if (typeof PiCodingAgent.getAgentDir === "function") return PiCodingAgent.getAgentDir();
  const envDir = process.env.PI_CODING_AGENT_DIR?.trim();
  if (envDir) return envDir;
  return join(homedir(), ".pi", "agent");
}

export function calmPreferencePath(): string {
  return join(calmAgentDir(), CALM_PREFERENCE_FILE_NAME);
}

// Section: Tolerant reads and atomic preference writes

// Calm is off by default and on any read error.
export function loadCalmPreference(): boolean {
  try {
    return readFileSync(calmPreferencePath(), "utf8").trim() === "on";
  } catch {
    return false;
  }
}

// Publish by atomic rename; report write failures so a toggle cannot silently fail to persist.
export function persistCalmPreference(active: boolean): void {
  const path = calmPreferencePath();
  try {
    mkdirSync(dirname(path), { recursive: true });
    const temporaryPath = `${path}.${process.pid}.${randomUUID()}.tmp`;
    try {
      writeFileSync(temporaryPath, active ? "on\n" : "off\n", {
        encoding: "utf8",
        flag: "wx",
        mode: 0o600,
      });
      renameSync(temporaryPath, path);
    } finally {
      rmSync(temporaryPath, { force: true });
    }
  } catch (error) {
    const reason = error instanceof Error ? error.message : String(error);
    throw new Error(`Pi Calm could not persist its preference to ${path}: ${reason}`);
  }
}
