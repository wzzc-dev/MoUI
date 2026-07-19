import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import test from "node:test";

const script = resolve("moui_shell/scripts/validate-ejected-lock.mjs");
const digest = value => `sha256:${createHash("sha256").update(value).digest("hex")}`;
const capabilityDigest = platform => digest(
  `shellApi=1\nembeddingApi=1\nplatform=${platform}\n` +
    "capabilities=surface,pointer,scroll,frame-scheduling,text-input,clipboard,accessibility,platform-views,host-channel\n",
);

const fixture = () => {
  const root = mkdtempSync(join(tmpdir(), "moui-shell-lock-"));
  const mouiRoot = join(root, "moui");
  const shellRoot = join(root, "moui_shell");
  const projectRoot = join(root, "app");
  const shellProject = join(projectRoot, "android_app");
  mkdirSync(mouiRoot, { recursive: true });
  mkdirSync(shellRoot, { recursive: true });
  mkdirSync(shellProject, { recursive: true });
  writeFileSync(join(mouiRoot, "moon.mod"), 'name = "wzzc-dev/moui"\nversion = "1.2.3"\n');
  writeFileSync(join(shellRoot, "moon.mod"), 'name = "wzzc-dev/moui_shell"\nversion = "1.2.3"\n');
  writeFileSync(join(projectRoot, "moui.project.json"), JSON.stringify({
    schemaVersion: 1,
    mouiVersion: "1.2.3",
    platforms: ["android"],
  }));
  writeFileSync(join(projectRoot, "shell.json"), JSON.stringify({
    schemaVersion: 1,
    shellApiVersion: 1,
    embeddingApiVersion: 1,
    shell: { profile: "handheld" },
    android: { runnerMode: "ejected" },
  }));
  const lock = {
    schemaVersion: 1,
    mode: "ejected",
    platform: "android",
    shellApiVersion: 1,
    embeddingApiVersion: 1,
    mouiVersion: "1.2.3",
    mouiShellVersion: "1.2.3",
    capabilitySnapshotDigest: capabilityDigest("android"),
    sourceTemplate: "android/runner/template",
    sourceTemplateDigest: digest("source"),
    configDigest: digest("config"),
    pluginDigest: digest("plugins"),
    pluginManifests: [],
    contentDigest: digest("content"),
    files: [],
  };
  const lockPath = join(shellProject, ".moui-shell.json");
  writeFileSync(lockPath, JSON.stringify(lock));
  return { root, mouiRoot, shellRoot, projectRoot, config: join(projectRoot, "shell.json"), lockPath, lock };
};

const validate = paths => spawnSync(process.execPath, [
  script,
  "--lock", paths.lockPath,
  "--platform", "android",
  "--moui-root", paths.mouiRoot,
  "--shell-root", paths.shellRoot,
  "--project-root", paths.projectRoot,
  "--app-config", paths.config,
], { encoding: "utf8" });

test("accepts an ejected lock pinned to both published packages", () => {
  const paths = fixture();
  try {
    const result = validate(paths);
    assert.equal(result.status, 0, result.stderr);
  } finally {
    rmSync(paths.root, { recursive: true, force: true });
  }
});

test("rejects a stale capability snapshot and package version", () => {
  const paths = fixture();
  try {
    paths.lock.capabilitySnapshotDigest = digest("stale");
    paths.lock.mouiShellVersion = "9.9.9";
    writeFileSync(paths.lockPath, JSON.stringify(paths.lock));
    const result = validate(paths);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /capabilitySnapshotDigest/);
  } finally {
    rmSync(paths.root, { recursive: true, force: true });
  }
});
