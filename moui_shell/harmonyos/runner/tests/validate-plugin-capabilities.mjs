#!/usr/bin/env node

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const testDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(testDir, "../../../..");
const read = path => readFileSync(resolve(repoRoot, path), "utf8");
const contains = (source, token, label) => {
  assert.ok(source.includes(token), `${label}: missing ${JSON.stringify(token)}`);
};
const before = (source, first, second, label) => {
  const firstIndex = source.indexOf(first);
  const secondIndex = source.indexOf(second);
  assert.ok(firstIndex >= 0, `${label}: missing ${JSON.stringify(first)}`);
  assert.ok(secondIndex >= 0, `${label}: missing ${JSON.stringify(second)}`);
  assert.ok(firstIndex < secondIndex, `${label}: ${JSON.stringify(first)} must precede ${JSON.stringify(second)}`);
};

test("HarmonyOS shell exposes generation-scoped generic plugin capabilities", () => {
  const plugins = read("moui_shell/harmonyos/runner/template/entry/src/main/ets/moui/MoUIPlugins.ets");
  for (const token of [
    "export class MoUILaunchOptions",
    "export interface MoUISemanticsNodeSnapshot",
    "export interface MoUISemanticsSnapshot",
    "export interface MoUISemanticsObserver",
    "export class MoUISemanticsCapability",
    "export class MoUIRuntimeInputDispatcher",
    "readonly sessionGeneration: number",
    "export class MoUIShellPluginCapabilities",
    "this.generation === sessionGeneration && this.epoch === dispatcherEpoch",
    "this.observers.forEach",
    "if (!dispatcher.isActive)",
  ]) {
    contains(plugins, token, "MoUIPlugins.ets");
  }

  const resetStart = plugins.indexOf("  resetSession(): void {");
  const destroyStart = plugins.indexOf("  destroyApplication(): void {", resetStart);
  assert.ok(resetStart >= 0 && destroyStart > resetStart);
  const resetBody = plugins.slice(resetStart, destroyStart);
  assert.ok(!resetBody.includes("this.observers.clear()"), "surface reset must retain observer registrations");
  contains(plugins.slice(destroyStart), "this.observers.clear()", "application destroy");
  contains(plugins.slice(destroyStart), "this.applicationDestroyed = true", "registry application destroy");
  before(
    plugins,
    "if (this.applicationDestroyed)",
    "plugins.forEach((plugin: MoUIPlugin)",
    "registry replacement after application destroy",
  );
});

test("HarmonyOS root publishes semantics after applying UI state", () => {
  const root = read("moui_shell/harmonyos/runner/template/entry/src/main/ets/moui/MoUIRoot.ets");
  before(
    root,
    "this.sessionGeneration = envelope.sessionGeneration;",
    "MoUIPluginRegistry.shared.activateSession(envelope.sessionGeneration, this.pluginRuntimeInput);",
    "session activation",
  );
  before(
    root,
    "this.semanticsNodes = payload.nodes;",
    "MoUIPluginRegistry.shared.publishSemantics(generation, payload.revision, snapshotNodes);",
    "semantics UI-thread publication",
  );
  contains(root, "MoUIPluginRegistry.shared.resetSession();", "surface reset");
});

test("HarmonyOS Ability maps the unified Want launch option and destroys plugin state", () => {
  const ability = read(
    "moui_shell/harmonyos/runner/template/entry/src/main/ets/entryability/EntryAbility.ets",
  );
  for (const token of [
    "import Want from '@ohos.app.ability.Want'",
    "const TEST_PROBE_LAUNCH_OPTION: string = 'moui.shell.testProbe'",
    "onCreate(want: Want",
    "onNewWant(want: Want",
    "want.parameters?.[TEST_PROBE_LAUNCH_OPTION]",
    "MoUIPluginRegistry.shared.setLaunchOption(TEST_PROBE_LAUNCH_OPTION, value)",
    "MoUIPluginRegistry.shared.destroyApplication()",
  ]) {
    contains(ability, token, "EntryAbility.ets");
  }
});

test("HarmonyOS test-probe gates and once-fires the stable-label service sequence", () => {
  const probe = read("moui_shell/test_probe/harmonyos/src/MoUIShellTestProbePlugin.ets");
  for (const token of [
    "this.registry.launchOption(TEST_PROBE_GATE)",
    "ProbeState.shared.serviceSmokeFired > 0",
    "this.fired = true",
    "SERVICE_TEXT_LABEL",
    "SERVICE_ACTION_LABEL",
    "textField.elementId",
    "action.elementId",
    "ProbeState.shared.increment('serviceSmokeFired')",
    "ProbeState.shared.increment('serviceSmokeCompleted')",
  ]) {
    contains(probe, token, "HarmonyOS test-probe");
  }
  const sequence = [
    "runtimeInput.dispatchAccessibility(textField.elementId, 1)",
    "runtimeInput.dispatchAccessibility(textField.elementId, 2, SERVICE_PROBE_TEXT)",
    "runtimeInput.dispatchTextInput(1, SERVICE_PROBE_TEXT, 0, 0)",
    "runtimeInput.dispatchTextInput(2, '', 0, SERVICE_PROBE_TEXT.length)",
    "runtimeInput.dispatchCommand(0)",
    "board.setDataSync",
    "runtimeInput.dispatchCommand(2)",
    "runtimeInput.dispatchCommand(1)",
    "runtimeInput.dispatchAccessibility(action.elementId, 1)",
    "runtimeInput.dispatchAccessibility(action.elementId, 0)",
  ];
  for (let index = 1; index < sequence.length; index += 1) {
    before(probe, sequence[index - 1], sequence[index], "test-probe service sequence");
  }
});

test("production HarmonyOS shell contains no service-probe labels or scripted actions", () => {
  const production = [
    "moui_shell/harmonyos/runner/template/entry/src/main/ets/moui/MoUIPlugins.ets",
    "moui_shell/harmonyos/runner/template/entry/src/main/ets/moui/MoUIRoot.ets",
    "moui_shell/harmonyos/runner/template/entry/src/main/ets/entryability/EntryAbility.ets",
  ];
  for (const path of production) {
    const source = read(path);
    for (const forbidden of [
      "Service probe text",
      "Activate service probe",
      "ime-shell-probe",
      "clipboard-service-probe",
      "service smoke begin",
    ]) {
      assert.ok(!source.includes(forbidden), `${path}: production shell contains ${JSON.stringify(forbidden)}`);
    }
  }
});
