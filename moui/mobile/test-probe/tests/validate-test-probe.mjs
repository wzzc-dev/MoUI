#!/usr/bin/env node

import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import {
  existsSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { basename, dirname, join, relative, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { readMobileApp } from "../../../scripts/mobile/app-config.mjs";
import { readMouiPluginManifest } from "../../../scripts/mobile/plugin-manifest.mjs";
import { prepareAndroidPlugins } from "../../android/prepare-plugins.mjs";

const testDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(testDir, "../../../..");
const mouiRoot = resolve(repoRoot, "moui");
const pluginRoot = resolve(mouiRoot, "mobile/test-probe");
const manifestPath = resolve(pluginRoot, "moui.plugin.json");
const pluginPath = "moui/mobile/test-probe/moui.plugin.json";
const pluginId = "dev.wzzc.moui.mobile.test-probe";
const platformViewKind = `${pluginId}.view`;
const hostChannel = `${pluginId}.channel`;
const canonicalCounters = [
  "platformViewCreate",
  "platformViewResize",
  "platformViewClip",
  "platformViewEvent",
  "platformViewDispose",
  "hostChannelSuccess",
  "hostChannelError",
  "hostChannelCancel",
  "hostChannelExactlyOnce",
  "hostChannelLateAfterDispose",
  "serviceSmokeFired",
  "serviceSmokeCompleted",
];

const read = path => readFileSync(resolve(repoRoot, path), "utf8");

const collectFiles = path => {
  const files = [];
  const visit = current => {
    if (statSync(current).isDirectory()) {
      for (const name of readdirSync(current).sort()) visit(resolve(current, name));
    } else {
      files.push(current);
    }
  };
  visit(path);
  return files;
};

const requireTokens = (source, tokens, label) => {
  for (const token of tokens) {
    assert.ok(source.includes(token), `${label}: missing ${JSON.stringify(token)}`);
  }
};

const requireOrdered = (source, tokens, label) => {
  let offset = 0;
  for (const token of tokens) {
    const index = source.indexOf(token, offset);
    assert.ok(index >= 0, `${label}: missing ordered token ${JSON.stringify(token)}`);
    offset = index + token.length;
  }
};

const between = (source, start, end, label) => {
  const startIndex = source.indexOf(start);
  assert.ok(startIndex >= 0, `${label}: missing start ${JSON.stringify(start)}`);
  const endIndex = source.indexOf(end, startIndex + start.length);
  assert.ok(endIndex > startIndex, `${label}: missing end ${JSON.stringify(end)}`);
  return source.slice(startIndex, endIndex);
};

const withPluginConfig = callback => {
  const exampleRoot = resolve(repoRoot, "examples/component_gallery");
  const configPath = resolve(
    exampleRoot,
    `.mobile-test-probe-${process.pid}-${Math.random().toString(16).slice(2)}.json`,
  );
  const config = JSON.parse(readFileSync(resolve(exampleRoot, "mobile.json"), "utf8"));
  config.mobile.plugins = [pluginPath];
  writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`);
  try {
    return callback(configPath);
  } finally {
    rmSync(configPath, { force: true });
  }
};

test("repo-only test probe is a valid three-platform plugin", () => {
  const plugin = readMouiPluginManifest(manifestPath, { workspaceRoot: repoRoot });
  assert.equal(plugin.id, pluginId);
  assert.equal(plugin.shellApi, 1);
  assert.deepEqual(Object.keys(plugin.platforms).sort(), ["android", "harmonyos", "ios"]);
  assert.deepEqual(plugin.platformViewKinds, [platformViewKind]);
  assert.deepEqual(plugin.hostChannels, [hostChannel]);
  assert.deepEqual(plugin.permissions, []);
  for (const platform of Object.values(plugin.platforms)) {
    assert.ok(platform.sources.length > 0);
    assert.ok(platform.resources.length > 0);
  }
});

test("platform fixtures emit the canonical runtime snapshot and lifecycle counters", () => {
  const sources = {
    android: read(
      "moui/mobile/test-probe/android/src/dev/wzzc/moui/mobile/testprobe/MoUIMobileTestProbePlugin.kt",
    ),
    ios: read("moui/mobile/test-probe/ios/src/MoUIMobileTestProbePlugin.swift"),
    harmonyos: read("moui/mobile/test-probe/harmonyos/src/MoUIMobileTestProbePlugin.ets"),
  };
  const sharedTokens = [
    pluginId,
    ...canonicalCounters,
    "moui-mobile test-probe snapshot=",
    "success",
    "error",
    "cancel",
    "exactly-once",
    "late-after-dispose",
    "snapshot",
  ];
  for (const [platform, source] of Object.entries(sources)) {
    requireTokens(source, sharedTokens, `${platform} test probe`);
  }

  const androidKeys = [...sources.android.matchAll(/\.put\("([A-Za-z]+)"/g)].map(match => match[1]);
  const swiftCounters = between(
    sources.ios,
    "private enum ProbeCounter: String, CaseIterable {",
    "private final class ProbeState",
    "iOS counter enum",
  );
  const iosKeys = [...swiftCounters.matchAll(/\bcase ([A-Za-z]+)/g)].map(match => match[1]);
  const harmonySnapshot = between(
    sources.harmonyos,
    "return JSON.stringify({",
    "    });",
    "HarmonyOS snapshot",
  );
  const harmonyKeys = [...harmonySnapshot.matchAll(/^\s+([A-Za-z]+): this\./gm)].map(match => match[1]);
  for (const [platform, keys] of Object.entries({ android: androidKeys, ios: iosKeys, harmonyos: harmonyKeys })) {
    assert.deepEqual(keys.sort(), canonicalCounters.slice().sort(), `${platform} snapshot keys drifted`);
  }
  assert.equal(
    (sources.android.match(/\.incrementAndGet\(\)/g) ?? []).length,
    1,
    "Android counter transitions must go through ProbeState.increment",
  );
  assert.equal(
    (sources.ios.match(/counters\[counter\.rawValue, default: 0\] \+= 1/g) ?? []).length,
    1,
    "iOS counter transitions must go through ProbeState.increment",
  );
  const harmonyCallSites = sources.harmonyos.slice(sources.harmonyos.indexOf("class ProbeServiceSmoke"));
  for (const counter of canonicalCounters) {
    assert.ok(
      !harmonyCallSites.includes(`.${counter} += 1`),
      `HarmonyOS ${counter} transition bypasses ProbeState.increment`,
    );
  }

  requireTokens(sources.android, [
    ": MoUIMobilePlugin",
    "override fun create",
    "override fun update",
    "override fun dispose",
    "if (completion.ok(request.payload))",
    "if (completion.error(request.payload.ifEmpty",
    "if (firstAccepted && !duplicateAccepted)",
    "ProbePendingTask.Kind.CANCEL",
    "ProbePendingTask.Kind.LATE_AFTER_DISPOSE",
    "Kind.CANCEL -> ProbeState.increment(ProbeState.hostChannelCancel)",
    "ProbeState.increment(ProbeState.hostChannelLateAfterDispose)",
  ], "Android test probe");
  requireTokens(sources.ios, [
    ": MOUIMobilePlugin",
    "makePlatformView",
    "updatePlatformView",
    "disposePlatformView",
    "if completion.succeed(payload: request.payload)",
    "if completion.fail(payload:",
    "if firstAccepted && !duplicateAccepted",
    "kind: .cancel",
    "kind: .lateAfterDispose",
    "case .cancel:\n      ProbeState.shared.increment(.hostChannelCancel)",
    "ProbeState.shared.increment(.hostChannelLateAfterDispose)",
  ], "iOS test probe");
  requireTokens(sources.harmonyos, [
    "implements MoUIPlugin",
    "create(_id: string",
    "update(controller: NodeController",
    "dispose(controller: NodeController",
    "new FrameNode(uiContext)",
    "renderNode.backgroundColor",
    "probe.updateSize",
    "if (completion.ok(request.payload))",
    "if (completion.error(request.payload.length === 0",
    "if (firstAccepted && !duplicateAccepted)",
    "new ProbePendingTask(completion, request.operation)",
    "if (this.operation === 'cancel')",
    "ProbeState.shared.increment('hostChannelCancel')",
    "ProbeState.shared.increment('hostChannelLateAfterDispose')",
  ], "HarmonyOS test probe");

  const disposeBodies = {
    android: between(sources.android, "override fun dispose(view: View)", "private fun placementValue", "Android dispose"),
    ios: between(sources.ios, "func disposePlatformView(_ view: UIView)", "private final class ProbePendingTask", "iOS dispose"),
    harmonyos: between(sources.harmonyos, "dispose(controller: NodeController)", "class ProbePendingTask", "HarmonyOS dispose"),
  };
  for (const [platform, body] of Object.entries(disposeBodies)) {
    assert.ok(
      !body.includes("hostChannelLateAfterDispose"),
      `${platform} PlatformView late event must not count as Host Channel late-after-dispose`,
    );
  }
});

test("service probe is gated, exact-label, once-fire, ordered, and evidence-safe", () => {
  const definitions = {
    android: {
      source: read(
        "moui/mobile/test-probe/android/src/dev/wzzc/moui/mobile/testprobe/MoUIMobileTestProbePlugin.kt",
      ),
      start: "private object ProbeServiceSmoke",
      end: "private class ProbeTextView",
      gate: "if (!capabilities.launchOptions.isEnabled(TEST_PROBE_GATE) || fired.get())",
      exactLabels: [
        "it.label == SERVICE_TEXT_LABEL && it.role == \"TextField\"",
        "it.label == SERVICE_ACTION_LABEL && it.role == \"Button\"",
      ],
      onceFire: ["fired.compareAndSet(false, true)", "ProbeState.increment(ProbeState.serviceSmokeFired)"],
      evidenceGuards: [
        "if (imeCommitAccepted)", "if (copyAccepted)", "if (pasteAccepted)", "if (cutAccepted)",
        "if (actionFocusAccepted)", "if (actionActivateAccepted)",
      ],
    },
    ios: {
      source: read("moui/mobile/test-probe/ios/src/MoUIMobileTestProbePlugin.swift"),
      start: "private final class ProbeServiceSmoke",
      end: "public enum MoUIMobileTestProbePlugin",
      gate: "capabilities.launchOptions.isEnabled(testProbeGate)",
      exactLabels: [
        "$0.label == serviceTextLabel && $0.role == \"TextField\"",
        "$0.label == serviceActionLabel && $0.role == \"Button\"",
      ],
      onceFire: ["!self.fired", "self.fired = true", "ProbeState.shared.increment(.serviceSmokeFired)"],
      evidenceGuards: [
        "if imeCommitAccepted", "if copyAccepted", "if pasteAccepted", "if cutAccepted",
        "if actionFocusAccepted", "if actionActivateAccepted",
      ],
    },
    harmonyos: {
      source: read("moui/mobile/test-probe/harmonyos/src/MoUIMobileTestProbePlugin.ets"),
      start: "class ProbeServiceSmoke",
      end: "class ProbeNodeController",
      gate: "!this.launchOptionEnabled(this.registry.launchOption(TEST_PROBE_GATE))",
      exactLabels: [
        "this.findNode(snapshot.nodes, SERVICE_TEXT_LABEL, 'TextField')",
        "this.findNode(snapshot.nodes, SERVICE_ACTION_LABEL, 'Button')",
        "nodes[index].label === label && nodes[index].role === role",
      ],
      onceFire: [
        "this.fired || ProbeState.shared.serviceSmokeFired > 0",
        "this.fired = true",
        "ProbeState.shared.increment('serviceSmokeFired')",
      ],
      evidenceGuards: [
        "if (imeCommitAccepted)", "if (copyAccepted)", "if (pasteAccepted)", "if (cutAccepted)",
        "if (actionFocusAccepted)", "if (actionActivateAccepted)",
      ],
    },
  };
  const orderedSequence = [
    "textFocusAccepted",
    "setTextAccepted",
    "imeCommitAccepted",
    "selectionAccepted",
    "copyAccepted",
    "clipboard-service-probe",
    "pasteAccepted",
    "cutAccepted",
    "actionFocusAccepted",
    "actionActivateAccepted",
  ];
  const evidenceMarkers = [
    "moui-mobile service ime edit kind=commit",
    "moui-mobile service smoke copy",
    "moui-mobile service smoke paste",
    "moui-mobile service smoke cut",
    "moui-mobile service accessibility focus id=",
    "moui-mobile service accessibility action=activate id=",
  ];
  for (const [platform, definition] of Object.entries(definitions)) {
    const body = between(definition.source, definition.start, definition.end, `${platform} service probe`);
    requireTokens(body, [definition.gate, ...definition.exactLabels, ...definition.onceFire], `${platform} service probe`);
    requireTokens(body, definition.evidenceGuards, `${platform} evidence guards`);
    requireOrdered(body, orderedSequence, `${platform} service sequence`);
    requireOrdered(
      body,
      definition.evidenceGuards.flatMap((guard, index) => [guard, evidenceMarkers[index]]),
      `${platform} accepted-only evidence logs`,
    );
    assert.ok(
      body.indexOf(definition.gate) < body.indexOf("textFocusAccepted"),
      `${platform} disabled gate must return before any runtime input dispatch`,
    );
    assert.ok(!body.includes("contains("), `${platform} service labels must use exact matching`);
  }
});

test("runtime input dispatchers reject reset generations and epochs", () => {
  const capabilities = {
    android: read("moui/mobile/android/src/main/kotlin/dev/wzzc/moui/mobile/MoUIMobileCapabilities.kt"),
    ios: read("moui/mobile/ios/Sources/MoUIMobileShell/MoUIMobileCapabilities.swift"),
    harmonyos: read("moui/mobile/harmonyos/template/entry/src/main/ets/moui/MoUIPlugins.ets"),
  };
  const resetBodies = {
    android: between(
      capabilities.android,
      "internal fun resetSession() {",
      "internal fun observe",
      "Android resetSession",
    ),
    ios: between(
      capabilities.ios,
      "func resetSession() {",
      "fileprivate func observe",
      "iOS resetSession",
    ),
    harmonyos: between(
      capabilities.harmonyos,
      "resetSession(): void {",
      "destroyApplication(): void {",
      "HarmonyOS resetSession",
    ),
  };
  requireTokens(resetBodies.android, [
    "generation = null",
    "epoch += 1",
  ], "Android runtime input reset");
  requireTokens(capabilities.android, [
    "generation == sessionGeneration && epoch == dispatcherEpoch",
    "if (isCurrent(sessionGeneration, dispatcherEpoch)) operation() else false",
  ], "Android runtime input reset");
  requireTokens(resetBodies.ios, [
    "generation = nil",
    "epoch &+= 1",
  ], "iOS runtime input reset");
  requireTokens(capabilities.ios, [
    "self.generation == generation && self.epoch == epoch",
    "guard isCurrent(generation: generation, epoch: epoch) else { return false }",
  ], "iOS runtime input reset");
  requireTokens(resetBodies.harmonyos, [
    "this.generation = 0",
    "this.epoch += 1",
  ], "HarmonyOS runtime input reset");
  requireTokens(capabilities.harmonyos, [
    "this.generation === sessionGeneration && this.epoch === dispatcherEpoch",
    "if (!this.isCurrent(sessionGeneration, dispatcherEpoch)",
  ], "HarmonyOS runtime input reset");
});

test("mobile app config resolves the fixture without production defaults", () => {
  withPluginConfig(configPath => {
    const app = readMobileApp("component_gallery", {
      workspaceRoot: repoRoot,
      mouiRoot,
      appConfigPath: configPath,
    });
    assert.deepEqual(app.plugins.map(plugin => plugin.id), [pluginId]);
    assert.equal(app.plugins[0].platforms.android.entry,
      "dev.wzzc.moui.mobile.testprobe.MoUIMobileTestProbePlugin");
    assert.equal(app.plugins[0].platforms.ios.entry, "MoUIMobileTestProbePlugin");
    assert.equal(app.plugins[0].platforms.harmonyos.entry, "MoUIMobileTestProbePlugin");
  });
});

test("iOS managed resolver compiles the fixture into the generated app module", () => {
  withPluginConfig(configPath => {
    const output = mkdtempSync(join(tmpdir(), "moui-ios-test-probe-"));
    try {
      const swiftPath = resolve(output, "MOUIGeneratedConfiguration.swift");
      const resolvedPath = resolve(output, "managed-shell.json");
      execFileSync("node", [
        resolve(mouiRoot, "mobile/ios/resolve-managed-shell.mjs"),
        "--workspace-root", repoRoot,
        "--moui-root", mouiRoot,
        "--app", "component_gallery",
        "--app-config", configPath,
        "--renderer", "auto",
        "--shell-mode", "managed",
        "--output-swift", swiftPath,
        "--output-manifest", resolvedPath,
      ]);
      requireTokens(readFileSync(swiftPath, "utf8"), [
        "MoUIMobileTestProbePlugin.self",
      ], "generated iOS plugin registry");
      const resolved = JSON.parse(readFileSync(resolvedPath, "utf8"));
      assert.deepEqual(resolved.pluginTypes, ["MoUIMobileTestProbePlugin"]);
      assert.ok(resolved.swiftSources.some(path => basename(path) === "MoUIMobileTestProbePlugin.swift"));
      assert.ok(resolved.resources.some(path => path === resolve(pluginRoot, "ios/resources")));
    } finally {
      rmSync(output, { recursive: true, force: true });
    }
  });
});

test("Android managed resolver stages source, resources, and generated registry", () => {
  withPluginConfig(configPath => {
    const app = readMobileApp("component_gallery", {
      workspaceRoot: repoRoot,
      mouiRoot,
      appConfigPath: configPath,
    });
    const output = mkdtempSync(join(tmpdir(), "moui-android-test-probe-"));
    try {
      const resolved = prepareAndroidPlugins({
        plugins: app.plugins,
        buildDir: output,
        shellMode: "managed",
      });
      assert.equal(resolved.plugins.length, 1);
      assert.equal(resolved.plugins[0].id, pluginId);
      assert.ok(resolved.plugins[0].sources.some(path =>
        basename(path) === "MoUIMobileTestProbePlugin.kt"));
      assert.ok(resolved.plugins[0].resources.some(path =>
        path.endsWith(join("values", "plugin-000-strings.xml"))));
      const registry = readFileSync(resolved.registryFile, "utf8");
      requireTokens(registry, [
        "dev.wzzc.moui.mobile.testprobe.MoUIMobileTestProbePlugin()",
        `installPlugin(applicationContext, \"${pluginId}\"`,
      ], "generated Android plugin registry");
    } finally {
      rmSync(output, { recursive: true, force: true });
    }
  });
});

test("HarmonyOS managed resolver stages source, resources, and generated registry", () => {
  withPluginConfig(configPath => {
    const output = mkdtempSync(join(tmpdir(), "moui-harmony-test-probe-"));
    const shell = resolve(output, "shell");
    try {
      execFileSync("node", [
        resolve(mouiRoot, "mobile/harmonyos/resolve-managed-shell.mjs"),
        "--workspace-root", repoRoot,
        "--moui-root", mouiRoot,
        "--app", "component_gallery",
        "--app-config", configPath,
        "--renderer", "auto",
        "--output", shell,
      ]);
      const generated = readFileSync(
        resolve(shell, "entry/src/main/ets/moui/MoUIGeneratedPlugins.ets"),
        "utf8",
      );
      requireTokens(generated, [
        "MoUIMobileTestProbePlugin as MoUIGeneratedPlugin0",
        "new MoUIGeneratedPlugin0()",
      ], "generated HarmonyOS plugin registry");
      const managed = JSON.parse(
        readFileSync(resolve(shell, ".moui-managed-shell.json"), "utf8"),
      );
      assert.deepEqual(managed.plugins.map(plugin => plugin.id), [pluginId]);
      assert.equal(managed.plugins[0].sources.length, 1);
      assert.equal(managed.plugins[0].resources.length, 1);
      const stagedSource = resolve(shell, managed.plugins[0].sources[0]);
      assert.ok(existsSync(stagedSource), "HarmonyOS plugin source was not staged");
      assert.ok(readFileSync(stagedSource, "utf8").includes(pluginId));
      const stagedResource = resolve(shell, managed.plugins[0].resources[0]);
      assert.ok(
        existsSync(resolve(stagedResource, "test-probe.json")),
        "HarmonyOS plugin resource was not staged",
      );
    } finally {
      rmSync(output, { recursive: true, force: true });
    }
  });
});

test("production canonical shell carries no test-probe behavior", () => {
  const productionRoots = [
    "moui/mobile/android/src",
    "moui/mobile/android/template",
    "moui/mobile/ios/Sources",
    "moui/mobile/ios/bridge",
    "moui/mobile/ios/template",
    "moui/mobile/harmonyos/src",
    "moui/mobile/harmonyos/template",
  ];
  const forbidden = [
    pluginId,
    "moui-mobile-test-probe-platform-view",
    "Service probe text",
    "Activate service probe",
    "ime-mobile-probe",
    "clipboard-service-probe",
    "moui-mobile service smoke begin",
    "moui-mobile service smoke copy",
    "moui-mobile service smoke paste",
    "moui-mobile service smoke cut",
  ];
  for (const root of productionRoots) {
    for (const path of collectFiles(resolve(repoRoot, root))) {
      const source = readFileSync(path, "utf8");
      for (const token of forbidden) {
        assert.ok(
          !source.includes(token),
          `${relative(repoRoot, path)}: production shell includes test behavior ${JSON.stringify(token)}`,
        );
      }
    }
  }
});
