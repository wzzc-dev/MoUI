import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import test from "node:test";

import { readShellApp } from "../../scripts/app-config.mjs";
import { resolveAndroidManagedShell } from "./resolve-shell.mjs";

const repoRoot = resolve(import.meta.dirname, "../../..");
const shellRoot = join(repoRoot, "moui_shell");
const config = mode => ({
  schemaVersion: 1, id: "fixture", displayName: "Android Fixture", artifactName: "fixture", appPackage: "app", shellApiVersion: 1, embeddingApiVersion: 1,
  shell: { profile: "handheld", renderer: "auto", systemUi: { fullscreen: true, statusBar: "visible" }, orientation: "landscape", resources: ["res"], permissions: ["camera"], plugins: [] },
  android: { applicationId: "dev.example.fixture", runnerMode: mode, minSdk: 23 },
});

test("managed resolver emits owned manifest and resources from strict shell.json", () => {
  const root = mkdtempSync(join(tmpdir(), "moui-shell-android-"));
  try {
    mkdirSync(join(root, "android_skia"), { recursive: true });
    mkdirSync(join(root, "res/values"), { recursive: true });
    writeFileSync(join(root, "android_skia/moon.pkg"), 'options("is-main": true)\n');
    writeFileSync(join(root, "res/values/strings.xml"), "<resources/>\n");
    writeFileSync(join(root, "shell.json"), JSON.stringify(config("managed")));
    const app = readShellApp("fixture", { workspaceRoot: root, mouiRoot: join(repoRoot, "moui"), shellRoot, skiaRoot: join(repoRoot, "moui_skia") });
    const result = resolveAndroidManagedShell({ app, buildDir: join(root, "build"), workspaceRoot: root });
    assert.match(readFileSync(result.manifestPath, "utf8"), /dev\.wzzc\.moui\.shell\.MoUIActivity/);
    assert.equal(result.runnerMode, "managed");
    assert.equal(result.shellApiVersion, 1);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("ejected resolver preserves app-owned Android resources", () => {
  const root = mkdtempSync(join(tmpdir(), "moui-shell-android-ejected-"));
  try {
    mkdirSync(join(root, "android_skia"), { recursive: true });
    writeFileSync(join(root, "android_skia/moon.pkg"), 'options("is-main": true)\n');
    writeFileSync(join(root, "shell.json"), JSON.stringify(config("ejected")));
    const app = readShellApp("fixture", { workspaceRoot: root, mouiRoot: join(repoRoot, "moui"), shellRoot, skiaRoot: join(repoRoot, "moui_skia") });
    const result = resolveAndroidManagedShell({ app, buildDir: join(root, "build"), workspaceRoot: root });
    assert.equal(result.configurationOwnership, "project-owned");
    assert.equal(result.manifestPath, null);
  } finally { rmSync(root, { recursive: true, force: true }); }
});
