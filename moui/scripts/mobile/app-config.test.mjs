import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
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
