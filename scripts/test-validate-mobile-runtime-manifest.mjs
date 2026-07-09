#!/usr/bin/env node

import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const tmp = mkdtempSync(join(tmpdir(), "moui-mobile-runtime-manifest-"));
const validator = "scripts/validate-mobile-runtime-manifest.mjs";

const baseManifest = (overrides = {}) => ({
  schemaVersion: 1,
  mode: "mobile-runtime-smoke",
  generatedBy: "scripts/record-mobile-runtime-smoke.mjs",
  platform: "ios",
  app: "component_gallery",
  status: "passed",
  build: {
    fallbackSkia: false,
    artifact: "artifacts/ios/component_gallery/ComponentGallery.app",
    command: "scripts/build-mobile-ios-app.sh --app component_gallery",
  },
  artifacts: {
    screenshot: "artifacts/mobile-runtime/ios/component_gallery/screenshot.png",
    log: "artifacts/mobile-runtime/ios/component_gallery/runtime.log",
  },
  screenshot: {
    width: 390,
    height: 844,
    totalPixels: 329160,
    contentPixels: 42000,
    distinctColorBuckets: 20,
  },
  observations: {
    lifecycleAttach: "yes",
    lifecycleDetach: "yes",
    nonblankFirstFrame: "yes",
    resize: "yes",
    representativeInput: "yes",
    scrollInput: "yes",
    cleanShutdown: "yes",
    ime: "pending",
    clipboard: "pending",
    accessibility: "pending",
    asyncImage: "pending",
    realDeviceSigning: "pending",
  },
  evidenceBoundary: "non-fallback matching-host smoke evidence; fallback builds are packaging only",
  ...overrides,
});

const run = (manifest, args = []) => {
  const path = join(tmp, `${Math.random().toString(16).slice(2)}.json`);
  writeFileSync(path, JSON.stringify(manifest, null, 2));
  return spawnSync("node", [validator, path, ...args], { encoding: "utf8" });
};

const assert = (condition, message) => {
  if (!condition) {
    console.error(message);
    process.exit(1);
  }
};

let result = run(baseManifest(), ["--require-passed"]);
assert(result.status === 0, `expected valid manifest, got ${result.status}\n${result.stdout}\n${result.stderr}`);

result = run(baseManifest({ build: { fallbackSkia: true, artifact: "x", command: "x" } }), ["--require-passed"]);
assert(result.status !== 0, "fallback manifest must not validate as passed");

result = run(baseManifest({ observations: { ...baseManifest().observations, scrollInput: "pending" } }), ["--require-passed"]);
assert(result.status !== 0, "component_gallery must require scrollInput when passed");

result = run(baseManifest({ app: "counter", observations: { ...baseManifest().observations, scrollInput: "pending" } }), ["--require-passed"]);
assert(result.status === 0, "counter may leave scrollInput pending");

result = run(baseManifest({ status: "failed", screenshot: { width: 0, height: 0, totalPixels: 0, contentPixels: 0, distinctColorBuckets: 0 } }));
assert(result.status === 0, "failed diagnostic manifest should validate without --require-passed");

console.log("mobile runtime manifest validator tests passed");
