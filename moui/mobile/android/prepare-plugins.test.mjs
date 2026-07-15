import assert from "node:assert/strict";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

import { readMouiPluginManifest } from "../../scripts/mobile/plugin-manifest.mjs";
import { prepareAndroidPlugins, validateAndroidPluginEntry } from "./prepare-plugins.mjs";

const androidRoot = dirname(fileURLToPath(import.meta.url));

const withWorkspace = callback => {
  const workspace = mkdtempSync(join(tmpdir(), "moui-android-plugins-"));
  try {
    callback(workspace);
  } finally {
    rmSync(workspace, { recursive: true, force: true });
  }
};

const createPlugin = (workspace, name, options = {}) => {
  const root = join(workspace, name);
  mkdirSync(join(root, "android", "src"), { recursive: true });
  mkdirSync(join(root, "android", "res", "values"), { recursive: true });
  writeFileSync(
    join(root, "android", "src", "SamplePlugin.kt"),
    "package dev.example\npublic class SamplePlugin\n",
  );
  writeFileSync(
    join(root, "android", "src", "PluginHelper.java"),
    "package dev.example; public final class PluginHelper {}\n",
  );
  writeFileSync(
    join(root, "android", "res", "values", "strings.xml"),
    `<resources><string name="${name}">${name}</string></resources>\n`,
  );
  return {
    id: options.id || `dev.example.${name}`,
    path: join(root, "moui.plugin.json"),
    root,
    platforms: {
      android: {
        sources: ["android/src"],
        resources: ["android/res"],
        entry: options.entry || "dev.example.SamplePlugin",
      },
    },
  };
};

test("managed Android plugins stage Kotlin, Java, resources, and a direct registry", () => {
  withWorkspace(workspace => {
    const buildDir = join(workspace, "build");
    const plugin = createPlugin(workspace, "sample");
    const result = prepareAndroidPlugins({ plugins: [plugin], buildDir, shellMode: "managed" });
    assert.equal(result.enabled, true);
    assert.equal(result.plugins.length, 1);
    assert.ok(existsSync(join(
      result.kotlinSourceDir,
      "plugin-000", "android", "src", "SamplePlugin.kt",
    )));
    assert.ok(existsSync(join(
      result.javaSourceDir,
      "plugin-000", "android", "src", "PluginHelper.java",
    )));
    assert.ok(existsSync(join(result.resourceDir, "values", "plugin-000-strings.xml")));
    const registry = readFileSync(result.registryFile, "utf8");
    assert.match(registry, /dev\.example\.SamplePlugin\(\)/);
    assert.match(registry, /plugin: MoUIMobilePlugin/);
    assert.match(registry, /context\.applicationContext/);
    assert.match(registry, /capabilities: MoUIMobilePluginCapabilities/);
    assert.match(registry, /plugin\.install\(applicationContext, capabilities\)/);
    assert.match(registry, /installedIds\.add\(expectedId\)/);
    assert.match(registry, /manifest=\$expectedId/);
  });
});

test("legacy Android preparation removes and does not expose managed plugin inputs", () => {
  withWorkspace(workspace => {
    const buildDir = join(workspace, "build");
    const plugin = createPlugin(workspace, "sample");
    const managed = prepareAndroidPlugins({ plugins: [plugin], buildDir, shellMode: "managed" });
    assert.ok(existsSync(managed.root));
    const legacy = prepareAndroidPlugins({ plugins: [plugin], buildDir, shellMode: "legacy" });
    assert.equal(legacy.enabled, false);
    assert.equal(legacy.registryFile, "");
    assert.deepEqual(legacy.plugins, []);
    assert.equal(existsSync(legacy.root), false);
  });
});

test("Android plugin entries must be safe fully qualified type names", () => {
  assert.equal(validateAndroidPluginEntry("dev.example.SamplePlugin"), "dev.example.SamplePlugin");
  for (const entry of ["SamplePlugin", "dev.example.Plugin()", "dev.when.Plugin", "dev.example.X;evil"] ) {
    assert.throws(() => validateAndroidPluginEntry(entry), /unsafe Android plugin entry|fully qualified/);
  }
});

test("managed Android plugins isolate values XML while rejecting true resource conflicts", () => {
  withWorkspace(workspace => {
    const first = createPlugin(workspace, "first");
    const second = createPlugin(workspace, "second");
    const merged = prepareAndroidPlugins({
      plugins: [first, second],
      buildDir: join(workspace, "values-build"),
      shellMode: "managed",
    });
    assert.ok(existsSync(join(merged.resourceDir, "values", "plugin-000-strings.xml")));
    assert.ok(existsSync(join(merged.resourceDir, "values", "plugin-001-strings.xml")));

    for (const plugin of [first, second]) {
      mkdirSync(join(plugin.root, "android", "res", "drawable"), { recursive: true });
      writeFileSync(join(plugin.root, "android", "res", "drawable", "shared.xml"), "<shape />\n");
    }
    assert.throws(
      () => prepareAndroidPlugins({
        plugins: [first, second],
        buildDir: join(workspace, "build"),
        shellMode: "managed",
      }),
      /Android plugin resource target conflict drawable\/shared\.xml/,
    );
  });
});

test("Android plugin fixture flows from manifest parser into generated registry", () => {
  withWorkspace(workspace => {
    const workspaceRoot = resolve(androidRoot, "../../..");
    const manifest = resolve(androidRoot, "tests/fixtures/plugin/moui.plugin.json");
    const plugin = readMouiPluginManifest(manifest, { workspaceRoot });
    const result = prepareAndroidPlugins({
      plugins: [plugin],
      buildDir: join(workspace, "build"),
      shellMode: "managed",
    });
    assert.equal(result.plugins[0].id, "dev.fixture.android-plugin");
    assert.match(
      readFileSync(result.registryFile, "utf8"),
      /dev\.fixture\.android\.FixturePlugin\(\)/,
    );
    assert.ok(existsSync(join(result.resourceDir, "values", "plugin-000-strings.xml")));
  });
});
