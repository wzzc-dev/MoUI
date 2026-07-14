#!/usr/bin/env node

import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  interpretMacosGpuSmokeLog,
  runGpuPromotionScaffold,
  validateGpuPromotionManifest,
} from "./lib/gpu-promotion-manifest.mjs";

const tmp = mkdtempSync(join(tmpdir(), "moui-gpu-promotion-"));

try {
  const smoke = interpretMacosGpuSmokeLog(
    [
      "surface_route=metal-gpu; surface_gpu=true",
      "MoUI Skia GPU Metal renderer smoke passed route=metal-gpu present_count=1",
      "worker-owned",
    ].join("\n"),
  );
  assert.equal(smoke.shortPathOk, true);
  assert.equal(smoke.presentCount, 1);

  const bad = interpretMacosGpuSmokeLog("surface_route=cpu-raster");
  assert.equal(bad.shortPathOk, false);

  const scaffold = runGpuPromotionScaffold({
    platform: "macos",
    outDir: tmp,
    mode: "scaffold",
    artifact: "artifacts/gpu-promotion/macos/test",
    exitOnFailure: false,
  });
  assert.equal(scaffold.status, 0, "MoonBit scaffold should succeed");

  const manifestPath = join(tmp, "gpu-promotion-manifest.json");
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  assert.equal(manifest.gpuPromoted, false);
  assert.equal(manifest.backend, "metal");
  assert.equal(manifest.evidenceProvenance.kind, "pending");

  const ok = validateGpuPromotionManifest(manifestPath, { requirePassed: false });
  assert.equal(ok.status, 0, `pending manifest should validate:\n${ok.stdout}\n${ok.stderr}`);

  const requirePassed = validateGpuPromotionManifest(manifestPath, {
    requirePassed: true,
  });
  assert.notEqual(requirePassed.status, 0, "pending must fail --require-passed");

  console.log("test-gpu-promotion-manifest-lib: ok");
} finally {
  rmSync(tmp, { recursive: true, force: true });
}
