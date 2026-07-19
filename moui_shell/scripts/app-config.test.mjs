import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import test from "node:test";

import { readShellApp } from "./app-config.mjs";

const repoRoot = resolve(import.meta.dirname, "../..");
const shellRoot = resolve(repoRoot, "moui_shell");
const baseConfig = () => ({
  schemaVersion: 1,
  id: "fixture",
  displayName: "Fixture",
  artifactName: "fixture",
  appPackage: "app",
  shellApiVersion: 1,
  embeddingApiVersion: 1,
  shell: { profile: "handheld", renderer: "auto", systemUi: { fullscreen: false, statusBar: "auto" }, orientation: "any", resources: [], permissions: [], plugins: [] },
  android: { applicationId: "dev.example.fixture", runnerMode: "managed", minSdk: 23 },
});

test("derives fixed v1 embedding contract without a build-contract registry", () => {
  const workspaceRoot = mkdtempSync(join(tmpdir(), "moui-shell-config-"));
  try {
    mkdirSync(join(workspaceRoot, "android_skia"), { recursive: true });
    writeFileSync(join(workspaceRoot, "android_skia/moon.pkg"), 'options("is-main": true)\n');
    const configPath = join(workspaceRoot, "shell.json");
    writeFileSync(configPath, `${JSON.stringify(baseConfig())}\n`);
    const app = readShellApp("fixture", { workspaceRoot, mouiRoot: join(repoRoot, "moui"), shellRoot, skiaRoot: join(repoRoot, "moui_skia"), appConfigPath: configPath });
    assert.equal(app.schemaVersion, 1);
    assert.equal(app.shell.profile, "handheld");
    assert.equal(app.android.moonPackage, "android_skia");
    assert.equal(app.android.exports.attachSurface, "moui_embedding_attach_surface");
    assert.equal(app.android.nativeLibrary, "moui_fixture_android");
    assert.equal(app.paths.shellRoot, shellRoot);
  } finally {
    rmSync(workspaceRoot, { recursive: true, force: true });
  }
});

test("requires plugin permissions in strict shell.json", () => {
  const workspaceRoot = mkdtempSync(join(tmpdir(), "moui-shell-plugin-"));
  try {
    mkdirSync(join(workspaceRoot, "android_skia"), { recursive: true });
    mkdirSync(join(workspaceRoot, "plugins/camera/android/src"), { recursive: true });
    writeFileSync(join(workspaceRoot, "android_skia/moon.pkg"), 'options("is-main": true)\n');
    writeFileSync(join(workspaceRoot, "plugins/camera/android/src/Camera.kt"), "class Camera\n");
    writeFileSync(join(workspaceRoot, "plugins/camera/moui.plugin.json"), JSON.stringify({ schemaVersion: 1, id: "camera", shellApi: 1, platforms: { android: { sources: ["android/src"], resources: [], entry: "dev.example.Camera" } }, platformViewKinds: [], hostChannels: [], permissions: ["camera"] }));
    const config = baseConfig();
    config.shell.plugins = ["plugins/camera/moui.plugin.json"];
    const configPath = join(workspaceRoot, "shell.json");
    writeFileSync(configPath, JSON.stringify(config));
    assert.throws(() => readShellApp("fixture", { workspaceRoot, mouiRoot: join(repoRoot, "moui"), shellRoot, skiaRoot: join(repoRoot, "moui_skia"), appConfigPath: configPath }), /requires undeclared permission "camera"/);
  } finally {
    rmSync(workspaceRoot, { recursive: true, force: true });
  }
});
