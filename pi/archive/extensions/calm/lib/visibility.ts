// Pi Calm - shared in-memory presentation flags; export/share temporarily force stock rendering.

// Adapted from the Firstmate project's Calm implementation.
// Copyright (c) 2026 Kun Chen. MIT License - see the LICENSE file in this directory.

let active = false;
let stockExportRendering = false;

/** True while Calm presentation filtering is enabled. */
export function calmPresentationIsActive(): boolean {
  return active;
}

export function setCalmPresentation(next: boolean): void {
  active = next;
}

/** True while an /export or /share render is in flight and stock output is required. */
export function calmStockExportRenderingIsActive(): boolean {
  return stockExportRendering;
}

export function setCalmStockExportRendering(next: boolean): void {
  stockExportRendering = next;
}

// Hide only collapsed thinking and known built-in tool shells; all other rows stay visible.
export function calmHidesTranscriptChrome(): boolean {
  return active && !stockExportRendering;
}
