// Pi Calm - deterministic boat animation with session-owned freeze/resume state.
// See ../README.md for cadence, resize, and widget lifetime details.

// Adapted from the Firstmate project's Calm implementation.
// Copyright (c) 2026 Kun Chen. MIT License - see the LICENSE file in this directory.

import type { Component, TUI } from "@earendil-works/pi-tui";

// The hull is symmetric and replaces waves on its row rather than adding a third row.
const HULL = "\\__/";
// A mainsail extends aft of the mast, so it trails behind the bow relative to travel.
const SAIL_RIGHT = "<|";
const SAIL_LEFT = "|>";
// Centers the two-cell sail over the four-cell hull.
const SAIL_OFFSET = 1;
const HULL_WIDTH = HULL.length;
const SAIL_WIDTH = SAIL_RIGHT.length;

// Bounded deterministic fixed-cell water phases. Every entry is exactly one column, so
// advancing the phase ripples the surface without changing visible width or row count.
const WAVE_CYCLE = ["~", "~", "-", "~"] as const;

// Standard ANSI foreground codes only: no theme lookup, bright variant, or 256/RGB.
const BLUE = "\u001b[34m";
const YELLOW = "\u001b[33m";
// Restores the default foreground so color never bleeds into padding or later frames.
const RESET = "\u001b[39m";

export const CALM_WORKING_SHIP_WIDGET_KEY = "calm-working-ship";
/** Scheduler period. One tick advances the water by one phase. */
export const CALM_WORKING_SHIP_TICK_MS = 220;
/** Boat moves one column every Nth tick, so it travels at 220 * 4 = 880ms per column. */
export const CALM_WORKING_SHIP_TICKS_PER_MOVE = 4;

export type CalmWorkingShipAnimation = {
  /** Render one frame that exactly fits `width`, clamping the track to it first. */
  render(width: number): string[];
  /** Advance one scheduler tick: water every tick, boat on its slower cadence. */
  tick(): void;
  restoreLastRendered(): void;
  /** Restore the normal initial column, direction, water phase, and cadence. */
  reset(): void;
  // Apply resizes while hidden without advancing the frozen animation.
  clampToWidth(width: number): void;
  /** Current hull column, exposed for deterministic motion assertions. */
  position(): number;
  /** Current travel direction: 1 travelling right, -1 travelling left. */
  direction(): number;
  /** Current water phase, exposed for deterministic ripple assertions. */
  waterPhase(): number;
};

// Section: Geometry and deterministic animation

/** Longest hull start column that still fits the sprite in `width` usable cells. */
function trackSpan(width: number): number {
  if (width >= HULL_WIDTH) return width - HULL_WIDTH;
  if (width >= SAIL_WIDTH) return width - SAIL_WIDTH;
  return 0;
}

export function createCalmWorkingShipAnimation(): CalmWorkingShipAnimation {
  let position = 0;
  let direction = 1;
  let span = 0;
  let phase = 0;
  let ticks = 0;
  let renderedPosition = position;
  let renderedDirection = direction;
  let renderedSpan = span;
  let renderedPhase = phase;
  let renderedTicks = ticks;

  // Reversing the moment the boat lands on an endpoint means the endpoint frame itself
  // already shows the new heading, so no frame at or after a bounce shows the old sail.
  const settleDirectionAtEdges = (): void => {
    if (span <= 0) return;
    if (position >= span) direction = -1;
    else if (position <= 0) direction = 1;
  };

  const applyWidth = (width: number): void => {
    if (width <= 0) {
      span = 0;
      position = 0;
      return;
    }
    span = trackSpan(width);
    position = Math.min(position, span);
    settleDirectionAtEdges();
  };

  const commitRenderedState = (): void => {
    renderedPosition = position;
    renderedDirection = direction;
    renderedSpan = span;
    renderedPhase = phase;
    renderedTicks = ticks;
  };

  const restoreLastRenderedState = (): void => {
    position = renderedPosition;
    direction = renderedDirection;
    span = renderedSpan;
    phase = renderedPhase;
    ticks = renderedTicks;
  };

  /** One colored run of water covering absolute columns [from, from + count). */
  const water = (from: number, count: number): string => {
    if (count <= 0) return "";
    let cells = "";
    for (let column = from; column < from + count; column += 1) {
      cells += WAVE_CYCLE[(column + phase) % WAVE_CYCLE.length];
    }
    return `${BLUE}${cells}${RESET}`;
  };

  const boat = (text: string): string => `${YELLOW}${text}${RESET}`;

  return {
    position: () => position,
    direction: () => direction,
    waterPhase: () => phase,

    restoreLastRendered: restoreLastRenderedState,

    reset(): void {
      position = 0;
      direction = 1;
      span = 0;
      phase = 0;
      ticks = 0;
      commitRenderedState();
    },

    clampToWidth(width: number): void {
      applyWidth(width);
    },

    tick(): void {
      ticks += 1;
      phase = (phase + 1) % WAVE_CYCLE.length;
      if (ticks % CALM_WORKING_SHIP_TICKS_PER_MOVE !== 0) return;
      if (span <= 0) {
        position = 0;
        return;
      }
      position = Math.min(span, Math.max(0, position + direction));
      settleDirectionAtEdges();
    },

    render(width: number): string[] {
      if (width <= 0) return [];

      // A resize lands here before the next frame, so recompute and clamp the track
      // immediately rather than trusting a position measured against the old width.
      applyWidth(width);

      const sail = direction >= 0 ? SAIL_RIGHT : SAIL_LEFT;

      let frame: string[];
      if (width < SAIL_WIDTH) {
        // Too narrow for even the sail: a deterministic single row of water.
        frame = [water(0, width)];
      } else if (width < HULL_WIDTH) {
        // Too narrow for the hull: the sail alone rides the water row.
        frame = [
          water(0, position) +
            boat(sail) +
            water(position + SAIL_WIDTH, width - position - SAIL_WIDTH),
        ];
      } else {
        frame = [
          " ".repeat(position + SAIL_OFFSET) + boat(sail),
          water(0, position) +
            boat(HULL) +
            water(position + HULL_WIDTH, width - position - HULL_WIDTH),
        ];
      }

      commitRenderedState();
      return frame;
    },
  };
}

// Section: Disposable TUI widget

// Pi disposes replacements under the same key, keeping one scheduler per widget.
// Disposal freezes caller-owned state; the next widget resumes without hidden elapsed time.
export function createCalmWorkingShipWidget(
  tui: TUI,
  animation: CalmWorkingShipAnimation = createCalmWorkingShipAnimation(),
): Component & { dispose(): void } {
  let disposed = false;
  const timer = setInterval(() => {
    if (disposed) return;
    animation.tick();
    tui.requestRender();
  }, CALM_WORKING_SHIP_TICK_MS);
  // The animation must never keep Pi's process alive on its own.
  timer.unref?.();

  return {
    render: (width) => (disposed ? [] : animation.render(width)),
    // Every frame is rebuilt from fixed standard ANSI codes, so there is no cache.
    invalidate: () => {},
    dispose: () => {
      if (disposed) return;
      disposed = true;
      clearInterval(timer);
      animation.restoreLastRendered();
    },
  };
}
