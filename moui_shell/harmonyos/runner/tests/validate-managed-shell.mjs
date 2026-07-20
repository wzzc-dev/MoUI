import assert from "node:assert/strict";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const repoRoot = resolve(import.meta.dirname, "../../../..");
const resolver = join(repoRoot, "moui_shell/harmonyos/runner/resolve-shell.mjs");

test("HarmonyOS runner stages only the handheld managed shell", () => {
  const root = mkdtempSync(join(tmpdir(), "moui-shell-harmonyos-"));
  try {
    mkdirSync(join(root, "harmonyos_skia"), { recursive: true });
    writeFileSync(join(root, "harmonyos_skia/moon.pkg"), 'options("is-main": true)\n');
    writeFileSync(join(root, "shell.json"), JSON.stringify({
      schemaVersion: 1, id: "fixture", displayName: "Harmony Fixture", artifactName: "fixture", appPackage: "app", shellApiVersion: 1, embeddingApiVersion: 1,
      shell: { profile: "handheld", renderer: "auto", systemUi: { fullscreen: false, statusBar: "auto" }, orientation: "any", resources: [], permissions: [], plugins: [] },
      harmonyos: { bundleName: "dev.example.fixture", productName: "Fixture", runnerMode: "managed", compatibleSdkVersion: 20 },
    }));
    const output = join(root, "harmonyos-project");
    const result = spawnSync(process.execPath, [resolver, "--workspace-root", root, "--moui-root", join(repoRoot, "moui"), "--app", "fixture", "--renderer", "auto", "--output", output], { encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr);
    assert.ok(existsSync(join(output, ".moui-managed-shell.json")));
    assert.match(readFileSync(join(output, "entry/src/main/ets/moui/MoUIGeneratedConfig.ets"), "utf8"), /moui-fixture-harmonyos/);
    const entryPackage = JSON.parse(readFileSync(join(output, "entry/oh-package.json5"), "utf8"));
    const nativeDependency = entryPackage.dependencies["libmoui_embedding_harmonyos.so"];
    assert.equal(nativeDependency, "file:./src/main/cpp/types/libmoui_embedding_harmonyos");
    assert.ok(existsSync(join(output, "entry", nativeDependency.slice("file:".length), "oh-package.json5")));
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("HarmonyOS CMake consumes the environment passed by Hvigor builds", () => {
  const entryCmake = readFileSync(join(
    repoRoot,
    "moui_shell/harmonyos/runner/template/entry/src/main/cpp/CMakeLists.txt",
  ), "utf8");
  assert.match(entryCmake, /ENV\{MOUI_PACKAGE_ROOT\}/);
  assert.match(entryCmake, /ENV\{MOUI_SHELL_PACKAGE_ROOT\}/);

  const embedderCmake = readFileSync(join(
    repoRoot,
    "moui_shell/harmonyos/embedder/cmake/MoUIShellHarmonyOS.cmake",
  ), "utf8");
  assert.match(embedderCmake, /ENV\{MOUI_EMBEDDING_NATIVE_CONFIG\}/);
  assert.match(embedderCmake, /ENV\{MOUI_HARMONYOS_FALLBACK\}/);

  const buildSource = readFileSync(join(
    repoRoot,
    "moui_cli/build_harmonyos.mbt",
  ), "utf8");
  for (const variable of [
    "MOUI_PACKAGE_ROOT",
    "MOUI_SHELL_PACKAGE_ROOT",
    "MOUI_EMBEDDING_NATIVE_CONFIG",
    "MOUI_HARMONYOS_FALLBACK",
  ]) {
    assert.match(buildSource, new RegExp(variable));
  }
});

test("HarmonyOS host updates accept the detached empty envelope", () => {
  const rootSource = readFileSync(join(
    repoRoot,
    "moui_shell/harmonyos/runner/template/entry/src/main/ets/moui/MoUIRoot.ets",
  ), "utf8");
  assert.match(
    rootSource,
    /envelope\.sessionGeneration === 0 && envelope\.updates\.length === 0/,
  );
  assert.match(rootSource, /envelope\.sessionGeneration <= 0/);
});
