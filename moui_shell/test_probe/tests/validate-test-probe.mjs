import assert from "node:assert/strict";
import { existsSync, readFileSync, statSync } from "node:fs";
import { resolve } from "node:path";
import test from "node:test";

import { readMouiPluginManifest } from "../../scripts/plugin-manifest.mjs";

const repoRoot = resolve(import.meta.dirname, "../../..");
const manifest = resolve(repoRoot, "moui_shell/test_probe/moui.plugin.json");

test("shell test probe is a three-platform shell plugin", () => {
  const probe = readMouiPluginManifest(manifest, { workspaceRoot: repoRoot });
  assert.equal(probe.shellApi, 1);
  assert.deepEqual(Object.keys(probe.platforms).sort(), ["android", "harmonyos", "ios"]);
  for (const platform of Object.values(probe.platforms)) {
    assert.ok(platform.sources.length > 0);
    assert.ok(platform.resources.length > 0);
  }
});

test("probe sources keep the canonical shell snapshot marker", () => {
  for (const relative of [
    "moui_shell/test_probe/android/src/dev/wzzc/moui/shell/testprobe/MoUIShellTestProbePlugin.kt",
    "moui_shell/test_probe/ios/src/MoUIShellTestProbePlugin.swift",
    "moui_shell/test_probe/harmonyos/src/MoUIShellTestProbePlugin.ets",
  ]) {
    const path = resolve(repoRoot, relative);
    assert.ok(existsSync(path), `missing ${relative}`);
    assert.match(readFileSync(path, "utf8"), /moui-shell test-probe snapshot=/);
  }
});

test("shell matrix shares one artifact root with child fixtures", () => {
  const matrix = readFileSync(
    resolve(repoRoot, "moui_shell/test_probe/tests/run-shell-matrix.sh"),
    "utf8",
  );
  assert.match(
    matrix,
    /artifact_root="\$\{MOUI_EMBEDDING_SHELL_CI_ROOT:-\$repo_root\/artifacts\/shell-ci\}"/,
  );
  assert.match(
    matrix,
    /export MOUI_EMBEDDING_SHELL_CI_ROOT="\$artifact_root"/,
  );

  const workflow = readFileSync(
    resolve(repoRoot, ".github/workflows/moui-shell-contracts.yml"),
    "utf8",
  );
  assert.doesNotMatch(workflow, /shell-shell-ci/);
  for (const platform of ["android", "ios", "harmonyos"]) {
    assert.match(
      workflow,
      new RegExp(`artifacts/shell-ci/${platform}/\\*\\*`),
      `shell workflow must upload ${platform} artifacts from artifacts/shell-ci`,
    );
  }

  for (const relative of [
    "moui_shell/test_probe/tests/build-clean-ejected-fixture.sh",
    "moui_shell/test_probe/tests/build-plugin-fixture.sh",
    "moui_shell/test_probe/tests/build-harmonyos-hvigor-fixture.sh",
  ]) {
    const source = readFileSync(resolve(repoRoot, relative), "utf8");
    assert.match(
      source,
      /artifact_root="\$\{MOUI_EMBEDDING_SHELL_CI_ROOT:-\$repo_root\/artifacts\/shell-ci\}"/,
      `${relative} must default to artifacts/shell-ci`,
    );
    assert.doesNotMatch(source, /shell-shell-ci/);
  }
});

test("directly invoked shell scripts remain executable", {
  skip: process.platform === "win32",
}, () => {
  for (const relative of [
    "moui_shell/harmonyos/runner/tests/build-plugin-fixture.sh",
    "moui_shell/test_probe/tests/build-clean-ejected-fixture.sh",
    "moui_shell/test_probe/tests/build-harmonyos-hvigor-fixture.sh",
    "moui_shell/test_probe/tests/build-plugin-fixture.sh",
    "moui_shell/test_probe/tests/run-shell-matrix.sh",
    "scripts/android-shell-runtime-evidence.sh",
    "scripts/harmonyos-shell-runtime-evidence.sh",
    "scripts/ios-shell-runtime-evidence.sh",
  ]) {
    assert.notEqual(
      statSync(resolve(repoRoot, relative)).mode & 0o111,
      0,
      `${relative} must be executable`,
    );
  }
});
