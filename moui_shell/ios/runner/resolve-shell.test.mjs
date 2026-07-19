import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const repoRoot = resolve(import.meta.dirname, "../../..");
const resolver = join(repoRoot, "moui_shell/ios/runner/resolve-shell.mjs");

test("iOS resolver consumes shell schema v1 and writes managed configuration", () => {
  const root = mkdtempSync(join(tmpdir(), "moui-shell-ios-"));
  try {
    mkdirSync(join(root, "ios_skia"), { recursive: true });
    writeFileSync(join(root, "ios_skia/moon.pkg"), 'options("is-main": true)\n');
    writeFileSync(join(root, "shell.json"), JSON.stringify({
      schemaVersion: 1, id: "fixture", displayName: "iOS Fixture", artifactName: "fixture", appPackage: "app", shellApiVersion: 1, embeddingApiVersion: 1,
      shell: { profile: "handheld", renderer: "auto", systemUi: { fullscreen: true, statusBar: "hidden" }, orientation: "landscape", resources: [], permissions: ["camera"], plugins: [] },
      ios: { bundleId: "dev.example.fixture", productName: "Fixture", runnerMode: "managed", deploymentTarget: "15.0" },
    }));
    const swift = join(root, "Generated.swift");
    const manifest = join(root, "manifest.json");
    const result = spawnSync(process.execPath, [resolver, "--workspace-root", root, "--moui-root", join(repoRoot, "moui"), "--skia-root", join(repoRoot, "moui_skia"), "--app", "fixture", "--renderer", "auto", "--shell-mode", "managed", "--output-swift", swift, "--output-manifest", manifest], { encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr);
    assert.match(readFileSync(swift, "utf8"), /fullscreen: true/);
    assert.equal(JSON.parse(readFileSync(manifest, "utf8")).deploymentTarget, "15.0");
  } finally { rmSync(root, { recursive: true, force: true }); }
});
