import assert from "node:assert/strict";
import test from "node:test";
import { createScrollStep } from "../pi/extensions/scroll-sensitivity/step.mjs";

test("changes the native step and restores its original value on disposal", () => {
  const tui = { mode: "fullscreen", wheelScrollLines: 1 };
  const step = createScrollStep(tui);
  assert.equal(step.apply(5), true);
  assert.equal(tui.wheelScrollLines, 5);
  step.apply(5);
  step.apply(1);
  step.apply(5);
  step.dispose();
  assert.equal(tui.wheelScrollLines, 1);
  step.dispose();
});

test("unsupported and readonly renderers fail safely without adding a field", () => {
  for (const tui of [{ mode: "fullscreen" }, { mode: "fullscreen", wheelScrollLines: "1" }, Object.freeze({ mode: "fullscreen", wheelScrollLines: 1 })]) {
    const before = { ...tui };
    const step = createScrollStep(tui);
    assert.equal(step.apply(5), false);
    step.dispose();
    assert.deepEqual(tui, before);
  }
});

test("regular mode is untouched and replacement fullscreen renderers are handled", () => {
  const tui = { mode: "regular" };
  const step = createScrollStep(tui);
  assert.equal(step.apply(5), true);
  assert.equal("wheelScrollLines" in tui, false);
  tui.mode = "fullscreen";
  tui.wheelScrollLines = 1;
  step.apply(5);
  tui.mode = "regular";
  delete tui.wheelScrollLines;
  step.apply(5);
  tui.mode = "fullscreen";
  tui.wheelScrollLines = 2;
  step.apply(5);
  step.dispose();
  assert.equal(tui.wheelScrollLines, 2);
});

test("disposal does not overwrite a later adjustment by another owner", () => {
  const tui = { mode: "fullscreen", wheelScrollLines: 1 };
  const step = createScrollStep(tui);
  step.apply(5);
  tui.wheelScrollLines = 3;
  step.dispose();
  assert.equal(tui.wheelScrollLines, 3);
});
