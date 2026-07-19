import assert from "node:assert/strict";
import {
  mkdirSync,
  mkdtempSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { readMouiPluginManifest, readMouiPluginManifests } from "./plugin-manifest.mjs";

const manifest = (id, overrides = {}) => ({
  schemaVersion: 1,
  id,
  shellApi: 1,
  platforms: {
    android: {
      sources: ["android/src"],
      resources: ["android/res"],
      entry: "dev.example.SamplePlugin",
    },
  },
  platformViewKinds: [`${id}.view`],
  hostChannels: [`${id}.service`],
  permissions: ["camera"],
  ...overrides,
});

const createPlugin = (workspace, directory, value) => {
  const root = join(workspace, directory);
  mkdirSync(join(root, "android/src"), { recursive: true });
  mkdirSync(join(root, "android/res"), { recursive: true });
  writeFileSync(join(root, "android/src/SamplePlugin.kt"), "class SamplePlugin\n");
  const path = join(root, "moui.plugin.json");
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
  return path;
};

const withWorkspace = callback => {
  const workspace = mkdtempSync(join(tmpdir(), "moui-plugin-"));
  try {
    callback(workspace);
  } finally {
    rmSync(workspace, { recursive: true, force: true });
  }
};

test("managed plugin accepts workspace-local Kotlin source and resources", () => {
  withWorkspace(workspace => {
    const path = createPlugin(workspace, "plugins/sample", manifest("sample"));
    const plugin = readMouiPluginManifest(path, { workspaceRoot: workspace });
    assert.equal(plugin.id, "sample");
    assert.equal(plugin.platforms.android.entry, "dev.example.SamplePlugin");
  });
});

test("managed plugin rejects build scripts and native dependencies", () => {
  withWorkspace(workspace => {
    const path = createPlugin(workspace, "plugins/sample", manifest("sample"));
    writeFileSync(join(workspace, "plugins/sample/build.gradle"), "dependencies {}\n");
    assert.throws(
      () => readMouiPluginManifest(path, { workspaceRoot: workspace }),
      /cannot contain dependency or build scripts/,
    );
    rmSync(join(workspace, "plugins/sample/build.gradle"));
    writeFileSync(join(workspace, "plugins/sample/android/res/vendor.so"), "binary");
    assert.throws(
      () => readMouiPluginManifest(path, { workspaceRoot: workspace }),
      /cannot contain native dependencies/,
    );
  });
});

test("managed plugin rejects unsupported source languages", () => {
  withWorkspace(workspace => {
    const value = manifest("sample");
    value.platforms.android.sources = ["android/src/bridge.cpp"];
    const path = createPlugin(workspace, "plugins/sample", value);
    writeFileSync(join(workspace, "plugins/sample/android/src/bridge.cpp"), "int bridge;\n");
    assert.throws(
      () => readMouiPluginManifest(path, { workspaceRoot: workspace }),
      /unsupported android source extension ".cpp"/,
    );
  });
});

test("managed plugin rejects a symlink escaping the plugin root", () => {
  withWorkspace(workspace => {
    const outside = join(workspace, "outside");
    mkdirSync(outside);
    writeFileSync(join(outside, "Outside.kt"), "class Outside\n");
    const value = manifest("sample");
    value.platforms.android.sources = ["linked"];
    const path = createPlugin(workspace, "plugins/sample", value);
    symlinkSync(outside, join(workspace, "plugins/sample/linked"));
    assert.throws(
      () => readMouiPluginManifest(path, { workspaceRoot: workspace }),
      /path escapes plugin root/,
    );
  });
});

test("plugin registry rejects duplicate kinds and channels", () => {
  withWorkspace(workspace => {
    const first = manifest("first", {
      platformViewKinds: ["shared.view"],
      hostChannels: ["shared.service"],
    });
    const second = manifest("second", {
      platformViewKinds: ["shared.view"],
      hostChannels: ["second.service"],
    });
    createPlugin(workspace, "plugins/first", first);
    createPlugin(workspace, "plugins/second", second);
    assert.throws(
      () => readMouiPluginManifests(
        ["plugins/first/moui.plugin.json", "plugins/second/moui.plugin.json"],
        { workspaceRoot: workspace },
      ),
      /"shared.view" is declared by both first and second/,
    );
  });
});

test("managed plugin rejects reserved moui namespace", () => {
  withWorkspace(workspace => {
    const path = createPlugin(workspace, "plugins/sample", manifest("moui.internal"));
    assert.throws(
      () => readMouiPluginManifest(path, { workspaceRoot: workspace }),
      /moui\.\* is a reserved namespace/,
    );
  });
});
