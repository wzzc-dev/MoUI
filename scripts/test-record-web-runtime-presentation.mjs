#!/usr/bin/env node

import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const tmp = mkdtempSync(join(tmpdir(), "moui-web-runtime-presentation-record-"));
const recorder = "scripts/record-web-runtime-presentation.mjs";

const failedManifestPath = join(tmp, "cdp-preflight-failed.json");
const result = spawnSync(process.execPath, [
  recorder,
  "--base-url",
  "http://127.0.0.1:18080",
  "--cdp-url",
  "http://127.0.0.1:9",
  "--manifest",
  failedManifestPath,
  "--timeout-ms",
  "250",
], { encoding: "utf8" });

if (result.status === 0) {
  console.error("CDP preflight failure should exit nonzero");
  process.exit(1);
}
if (!result.stdout.includes("web runtime presentation manifest:")) {
  console.error("CDP preflight failure should still write a manifest");
  console.error(result.stdout);
  console.error(result.stderr);
  process.exit(1);
}
if (
  !result.stderr.includes("web runtime presentation failed summary:") ||
  !result.stderr.includes("target showcase-web-wasm status=failed")
) {
  console.error("CDP preflight failure should print a structured failure summary");
  console.error(result.stdout);
  console.error(result.stderr);
  process.exit(1);
}

const manifest = JSON.parse(readFileSync(failedManifestPath, "utf8"));
if (
  manifest.overallStatus !== "failed" ||
  manifest.browser.product !== "unavailable" ||
  manifest.targets.length !== 2 ||
  manifest.platformObservations.surface !== "no" ||
  !manifest.targets.every(target =>
    target.status === "failed" &&
    target.observations.pageLoaded === "no" &&
    target.observations.transformPixels === "no" &&
    target.observations.radialGradient === "no" &&
    target.observations.colorEmojiPixels === "no" &&
    target.observations.zwjGrapheme === "no" &&
    target.observations.bidiLayout === "no" &&
    target.observations.paragraphWrapping === "no" &&
    target.observations.asyncImageSecondFrame === "no" &&
    target.screenshot.transformPixels.required === (target.name === "showcase-web-wasm") &&
    target.screenshot.radialGradient.required === (target.name === "showcase-web-wasm") &&
    target.screenshot.asyncImageSecondFrame.required === (target.name === "showcase-web-wasm") &&
    target.evidenceEvents.length === 0 &&
    target.consoleErrors.length > 0
  )
) {
  console.error("CDP preflight failure manifest did not record structured failed evidence");
  process.exit(1);
}

const validation = spawnSync(process.execPath, [
  "scripts/validate-web-runtime-presentation-manifest.mjs",
  failedManifestPath,
], { encoding: "utf8" });

if (validation.status !== 0) {
  console.error("CDP preflight failure manifest should validate without --require-passed");
  console.error(validation.stderr);
  process.exit(1);
}

console.log("web runtime presentation recorder tests: ok");
