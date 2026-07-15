import assert from "node:assert/strict";
import {
  chmodSync,
  copyFileSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";

import {
  applyManagedInfoPlist,
  validateDeploymentTarget,
  validatePermissionUsageDescriptions,
} from "./apply-managed-info-plist.mjs";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, "../../..");
const mouiRoot = resolve(repoRoot, "moui");
const skiaRoot = resolve(repoRoot, "moui_skia");
const resolver = resolve(scriptDir, "resolve-managed-shell.mjs");
const builder = resolve(mouiRoot, "scripts/mobile/build-ios-app.sh");

const createFixture = (t, {
  deploymentTarget = "16.2",
  permissions = ["camera", "notifications", "clipboard", "photos"],
  shellMode = "managed",
} = {}) => {
  const root = mkdtempSync(join(tmpdir(), "moui-ios-managed-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  mkdirSync(join(root, "assets"), { recursive: true });
  writeFileSync(join(root, "assets/icon.txt"), "fixture\n");
  const config = {
    schemaVersion: 2,
    id: "ios_fixture",
    displayName: "iOS Fixture",
    artifactName: "ios-fixture",
    appPackage: "app",
    shellApiVersion: 1,
    runtimeAbiVersion: 1,
    mobile: {
      renderer: "auto",
      systemUi: { fullscreen: true, statusBar: "hidden" },
      orientation: "landscape",
      resources: ["assets/icon.txt"],
      permissions,
      plugins: [],
    },
    ios: {
      bundleId: "dev.example.iosfixture",
      productName: "iOSFixture",
      shellMode,
      deploymentTarget,
    },
  };
  const configPath = join(root, "mobile.json");
  writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`);
  return { root, configPath };
};

const resolveFixture = (fixture, shellMode = "managed") => {
  const outputSwift = join(fixture.root, "Generated.swift");
  const outputManifest = join(fixture.root, "managed-shell.json");
  const result = spawnSync(process.execPath, [
    resolver,
    "--workspace-root", fixture.root,
    "--moui-root", mouiRoot,
    "--skia-root", skiaRoot,
    "--app", "ios_fixture",
    "--app-config", fixture.configPath,
    "--renderer", "skia-gpu",
    "--shell-mode", shellMode,
    "--output-swift", outputSwift,
    "--output-manifest", outputManifest,
  ], { encoding: "utf8" });
  return { result, outputSwift, outputManifest };
};

test("resolver preserves UI/resource behavior and emits managed iOS build settings", t => {
  const fixture = createFixture(t);
  const { result, outputSwift, outputManifest } = resolveFixture(fixture);
  assert.equal(result.status, 0, result.stderr);

  const swift = readFileSync(outputSwift, "utf8");
  assert.match(swift, /renderer: "skia-gpu"/);
  assert.match(swift, /fullscreen: true/);
  assert.match(swift, /statusBar: .*"hidden"/);
  assert.match(swift, /orientation: .*"landscape"/);

  const manifest = JSON.parse(readFileSync(outputManifest, "utf8"));
  assert.equal(manifest.deploymentTarget, "16.2");
  assert.deepEqual(manifest.permissions, ["camera", "notifications", "clipboard", "photos"]);
  assert.deepEqual(manifest.resources, [join(fixture.root, "assets/icon.txt")]);
  assert.deepEqual(
    manifest.permissionUsageDescriptions.map(({ permission, plistKey }) => ({ permission, plistKey })),
    [
      { permission: "camera", plistKey: "NSCameraUsageDescription" },
      { permission: "photos", plistKey: "NSPhotoLibraryUsageDescription" },
    ],
  );
  assert.ok(manifest.permissionUsageDescriptions.every(entry => entry.description.startsWith("iOS Fixture ")));
});

test("managed resolver rejects permissions that require an ejected shell", t => {
  const fixture = createFixture(t, { permissions: ["health"] });
  const { result } = resolveFixture(fixture);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /does not support mobile\.permissions entry "health"/);
  assert.match(result.stderr, /eject the iOS shell/);
});

test("ejected resolver leaves app-owned permission declarations unchanged", t => {
  const fixture = createFixture(t, { permissions: ["health"], shellMode: "ejected" });
  const { result, outputManifest } = resolveFixture(fixture, "ejected");
  assert.equal(result.status, 0, result.stderr);
  const manifest = JSON.parse(readFileSync(outputManifest, "utf8"));
  assert.deepEqual(manifest.permissionUsageDescriptions, []);
});

test("permission usage declarations are validated before plist mutation", () => {
  assert.equal(validateDeploymentTarget("15.0"), "15.0");
  assert.throws(() => validateDeploymentTarget("14.4"), /must be at least 15\.0/);
  assert.throws(
    () => validatePermissionUsageDescriptions([
      { permission: "camera", plistKey: "CFBundleName", description: "bad" },
    ]),
    /invalid permission usage declaration/,
  );
  assert.throws(
    () => validatePermissionUsageDescriptions([
      { permission: "camera", plistKey: "NSCameraUsageDescription", description: "one" },
      { permission: "camera", plistKey: "NSCameraUsageDescription", description: "two" },
    ]),
    /invalid permission usage declaration/,
  );
});

test("permission usage declarations are written structurally to Info.plist", {
  skip: process.platform !== "darwin" ? "plutil is an Apple platform tool" : false,
}, t => {
  const root = mkdtempSync(join(tmpdir(), "moui-ios-plist-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const plistPath = join(root, "Info.plist");
  const manifestPath = join(root, "managed-shell.json");
  copyFileSync(resolve(mouiRoot, "mobile/ios/template/Info.plist"), plistPath);
  writeFileSync(manifestPath, JSON.stringify({
    deploymentTarget: "16.2",
    permissionUsageDescriptions: [{
      permission: "camera",
      plistKey: "NSCameraUsageDescription",
      description: "Fixture needs the camera for a user-selected scan.",
    }],
  }));

  applyManagedInfoPlist({ manifestPath, plistPath });
  const result = spawnSync("plutil", ["-extract", "NSCameraUsageDescription", "raw", "-o", "-", plistPath], {
    encoding: "utf8",
  });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.trim(), "Fixture needs the camera for a user-selected scan.");
  const target = spawnSync("plutil", ["-extract", "MinimumOSVersion", "raw", "-o", "-", plistPath], {
    encoding: "utf8",
  });
  assert.equal(target.status, 0, target.stderr);
  assert.equal(target.stdout.trim(), "16.2");
});

const createFakeXcodebuild = root => {
  const bin = join(root, "bin");
  mkdirSync(bin, { recursive: true });
  const path = join(bin, "xcodebuild");
  writeFileSync(path, `#!/bin/sh
if [ "$1" = "-version" ]; then
  echo "Xcode 15.4"
  echo "Build version 15F31d"
  exit 0
fi
if [ -n "$MOUI_TEST_XCODE_CAPTURE" ]; then
  : > "$MOUI_TEST_XCODE_CAPTURE"
  for argument in "$@"; do
    printf '%s\\n' "$argument" >> "$MOUI_TEST_XCODE_CAPTURE"
  done
fi
exit 42
`);
  chmodSync(path, 0o755);
  return bin;
};

const runBuilder = (fixture, bin, extra = []) => spawnSync(builder, [
  "--app", "ios_fixture",
  "--workspace-root", fixture.root,
  "--moui-root", mouiRoot,
  "--skia-root", skiaRoot,
  "--app-config", fixture.configPath,
  "--build-dir", join(fixture.root, "build"),
  ...extra,
], {
  encoding: "utf8",
  env: {
    ...process.env,
    PATH: `${bin}:${process.env.PATH}`,
    MOUI_TEST_XCODE_CAPTURE: join(fixture.root, "xcode-arguments.txt"),
  },
});

test("managed build stages permission declarations and defaults to the configured deployment target", {
  skip: process.platform !== "darwin" ? "managed iOS staging requires plutil" : false,
}, t => {
  const fixture = createFixture(t, { deploymentTarget: "16.2", permissions: ["camera"] });
  const bin = createFakeXcodebuild(fixture.root);
  const result = runBuilder(fixture, bin);
  assert.equal(result.status, 42, result.stderr);
  const argumentsText = readFileSync(join(fixture.root, "xcode-arguments.txt"), "utf8");
  assert.match(argumentsText, /^IPHONEOS_DEPLOYMENT_TARGET=16\.2$/m);
  const stagedPlist = join(fixture.root, "build/ios-project/Info.plist");
  const plist = spawnSync("plutil", ["-p", stagedPlist], { encoding: "utf8" });
  assert.equal(plist.status, 0, plist.stderr);
  assert.match(plist.stdout, /"MinimumOSVersion" => "16\.2"/);
  assert.match(plist.stdout, /"NSCameraUsageDescription"/);
});

test("managed build rejects an explicit deployment target below the configured floor", t => {
  const fixture = createFixture(t, { deploymentTarget: "16.2", permissions: [] });
  const bin = createFakeXcodebuild(fixture.root);
  const result = runBuilder(fixture, bin, ["--deployment-target", "16.1"]);
  assert.equal(result.status, 2);
  assert.match(result.stderr, /below mobile\.json ios\.deploymentTarget 16\.2/);
});
