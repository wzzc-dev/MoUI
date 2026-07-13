#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const workerPath = resolve(repoRoot, "moui_skia/native/skia_stub_gpu_worker.cpp");
const workerApiPath = resolve(repoRoot, "moui_skia/native/native_gpu_worker_native.mbt");
const buildPath = resolve(repoRoot, "moui_skia/build.js");
const worker = readFileSync(workerPath, "utf8");
const workerApi = readFileSync(workerApiPath, "utf8");
const build = readFileSync(buildPath, "utf8");

const forbidden = [
  ["Skia readback", /\bread_pixels\b|\breadPixels\b/],
  ["CPU pixel presenter", /present_skia_pixels|present_rgba_pixels/],
  ["renderer read-frame path", /\bread_frame\s*\(/],
  ["platform CPU presenter", /CGImage|UIImage|StretchDIBits|wl_shm/],
];

const failures = [];
for (const [label, pattern] of forbidden) {
  const match = pattern.exec(worker);
  if (match) {
    const line = worker.slice(0, match.index).split("\n").length;
    failures.push(`${workerPath}:${line}: GPU worker contains forbidden ${label}`);
  }
}

if (!/readback_count:\s*0L/.test(workerApi)) {
  failures.push(`${workerApiPath}: native worker diagnostics must report readback_count: 0L`);
}

const androidStart = build.indexOf('platform === "android"');
const harmonyStart = build.indexOf('platform === "harmonyos"', androidStart);
const androidFlags = androidStart >= 0 && harmonyStart > androidStart
  ? build.slice(androidStart, harmonyStart)
  : "";
if (!androidFlags) {
  failures.push(`${buildPath}: Android Skia platform flags block was not found`);
} else if (androidFlags.includes("-lvulkan")) {
  failures.push(`${buildPath}: Android minSdk 23 GPU builds must dynamically load Vulkan, not link -lvulkan`);
}

if (failures.length > 0) {
  for (const failure of failures) console.error(failure);
  process.exit(1);
}

console.log("GPU worker no-readback guard: ok");
