// Pi Calm - remove collapsed thinking rows from display, preserving the original message.
// Probe Pi interfaces before patching; expanded thinking uses stock rendering.

// Adapted from the Firstmate project's Calm implementation.
// Copyright (c) 2026 Kun Chen. MIT License - see the LICENSE file in this directory.

import type { AssistantMessageComponent as PiAssistantMessageComponent } from "@earendil-works/pi-coding-agent";
import * as PiCodingAgent from "@earendil-works/pi-coding-agent";
import { calmHidesTranscriptChrome } from "./visibility.ts";

// Section: Pi message and presentation interfaces
type AssistantMessage = Parameters<PiAssistantMessageComponent["updateContent"]>[0];

type AssistantMessagePresentationState = {
  hiddenThinkingLabel: string;
  hideThinkingBlock: boolean;
  lastMessage?: AssistantMessage;
};

type CalmCollapsedThinkingPatch = {
  hidesThinking: () => boolean;
};

// Keep the introduction-version symbol stable so a compatible upgrade cannot
// double-patch a live process.
const CALM_COLLAPSED_THINKING_PATCH = Symbol.for(
  "pi-calm:collapsed-thinking-layout:pi-0.82.0",
);

// Section: Guarded adapter installation
export function installCalmCollapsedThinkingLayout(): void {
  const registry = globalThis as typeof globalThis & {
    [key: symbol]: CalmCollapsedThinkingPatch | undefined;
  };
  const hidesThinking = (): boolean => calmHidesTranscriptChrome();
  const installed = registry[CALM_COLLAPSED_THINKING_PATCH];
  if (installed) {
    installed.hidesThinking = hidesThinking;
    return;
  }

  const patch: CalmCollapsedThinkingPatch = { hidesThinking };
  const AssistantMessageComponent = PiCodingAgent.AssistantMessageComponent;
  if (typeof AssistantMessageComponent !== "function") {
    throw new Error("Pi Calm requires Pi AssistantMessageComponent");
  }
  const originalUpdateContent = AssistantMessageComponent.prototype.updateContent;
  if (typeof originalUpdateContent !== "function") {
    throw new Error("Pi Calm requires Pi AssistantMessageComponent.updateContent");
  }

  // Section: Collapsed rendering with original message preservation
  AssistantMessageComponent.prototype.updateContent = function (
    message: AssistantMessage,
  ): void {
    const state = this as unknown as AssistantMessagePresentationState;
    const hideThinking =
      state.hiddenThinkingLabel === "" &&
      state.hideThinkingBlock &&
      patch.hidesThinking();
    const presentationMessage = hideThinking
      ? {
          ...message,
          content: message.content.filter((block) => block.type !== "thinking"),
        }
      : message;

    originalUpdateContent.call(this, presentationMessage);
    if (presentationMessage !== message) state.lastMessage = message;
  };

  registry[CALM_COLLAPSED_THINKING_PATCH] = patch;
}
