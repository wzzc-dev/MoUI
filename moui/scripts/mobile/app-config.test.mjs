import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import test from "node:test";
import { readMobileApp } from "./app-config.mjs";

const repoRoot = resolve(import.meta.dirname, "../../..");

const legacyMetadata = {
  schemaVersion: 1,
  id: "legacy_fixture",
  displayName: "Legacy Fixture",
  artifactName: "legacy_fixture",
  appPackage: "app",
  mobile: { fullscreen: false, supportsScroll: false },
  android: { applicationId: "dev.example.legacy" },
};

const legacyContracts = {
  schemaVersion: 1,
  apps: {
    legacy_fixture: {
      android: {
        moonPackage: "android",
        generatedC: "android.c",
        nativeLibrary: "legacy_fixture",
        appArg: "legacy-fixture",
        moonbitMainAlias: "legacy_fixture_main",
        exports: {
          attachSurface: "legacy_attach",
          resize: "legacy_resize",
          dispatchPointer: "legacy_pointer",
          frameTick: "legacy_tick",
          renderFrame: "legacy_render",
          detachSurface: "legacy_detach",
        },
      },
    },
  },
};

test("schema v1 requires an explicit Release N compatibility flag", () => {
  const workspaceRoot = mkdtempSync(join(tmpdir(), "moui-mobile-config-"));
  try {
    const configPath = join(workspaceRoot, "mobile.json");
    const contractsPath = join(workspaceRoot, "contracts.json");
    writeFileSync(configPath, `${JSON.stringify(legacyMetadata)}\n`);
    writeFileSync(contractsPath, `${JSON.stringify(legacyContracts)}\n`);
    const options = {
      workspaceRoot,
      mouiRoot: join(repoRoot, "moui"),
      skiaRoot: join(repoRoot, "moui_skia"),
      appConfigPath: configPath,
      contractsPath,
    };

    assert.throws(
      () => readMobileApp("legacy_fixture", options),
      /requires the explicit legacy config flag/,
    );

    const app = readMobileApp("legacy_fixture", { ...options, allowLegacyConfig: true });
    assert.equal(app.schemaVersion, 1);
    assert.equal(app.deprecations[0].code, "mobile-config-schema-v1");
  } finally {
    rmSync(workspaceRoot, { recursive: true, force: true });
  }
});

test("managed plugin permissions must be granted by mobile.json", () => {
  const workspaceRoot = mkdtempSync(join(tmpdir(), "moui-mobile-plugin-config-"));
  try {
    const pluginRoot = join(workspaceRoot, "plugins/camera");
    mkdirSync(join(pluginRoot, "android/src"), { recursive: true });
    writeFileSync(join(pluginRoot, "android/src/CameraPlugin.kt"), "class CameraPlugin\n");
    writeFileSync(join(pluginRoot, "moui.plugin.json"), `${JSON.stringify({
      schemaVersion: 1,
      id: "camera",
      shellApi: 1,
      platforms: {
        android: {
          sources: ["android/src"],
          resources: [],
          entry: "dev.example.CameraPlugin",
        },
      },
      platformViewKinds: ["camera.preview"],
      hostChannels: ["camera.control"],
      permissions: ["camera"],
    })}\n`);
    const config = {
      schemaVersion: 2,
      id: "plugin_fixture",
      displayName: "Plugin Fixture",
      artifactName: "plugin_fixture",
      appPackage: "app",
      shellApiVersion: 1,
      runtimeAbiVersion: 1,
      mobile: {
        renderer: "auto",
        systemUi: { fullscreen: false, statusBar: "auto" },
        orientation: "any",
        resources: [],
        permissions: [],
        plugins: ["plugins/camera/moui.plugin.json"],
      },
      android: {
        applicationId: "dev.example.pluginfixture",
        shellMode: "managed",
        minSdk: 23,
      },
    };
    const configPath = join(workspaceRoot, "mobile.json");
    const contractsPath = join(workspaceRoot, "contracts.json");
    writeFileSync(configPath, `${JSON.stringify(config)}\n`);
    writeFileSync(contractsPath, '{"schemaVersion":1,"apps":{}}\n');
    assert.throws(
      () => readMobileApp("plugin_fixture", {
        workspaceRoot,
        mouiRoot: join(repoRoot, "moui"),
        skiaRoot: join(repoRoot, "moui_skia"),
        appConfigPath: configPath,
        contractsPath,
      }),
      /plugin camera requires undeclared permission "camera"/,
    );
  } finally {
    rmSync(workspaceRoot, { recursive: true, force: true });
  }
});
