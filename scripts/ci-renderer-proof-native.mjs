#!/usr/bin/env node

import { mkdirSync, writeFileSync, appendFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

const usage = () => {
  console.error("Usage: node scripts/ci-renderer-proof-native.mjs <wgpu-native|skia-native> <macos|windows|linux>");
  process.exit(2);
};

const [backend, platform] = process.argv.slice(2);
if (!backend || !platform) usage();
if (!["wgpu-native", "skia-native"].includes(backend)) usage();
if (!["macos", "windows", "linux"].includes(platform)) usage();

const proofDir = "artifacts/conformance/renderer-proof";
const platformDir = `artifacts/platform-evidence/${platform}`;
const logPath = `${proofDir}/${backend}-${platform}.log`;
const manifestPath = `${proofDir}/${backend}-${platform}.json`;
const artifactName = `moui-renderer-proof-${backend}-${platform}`;
mkdirSync(proofDir, { recursive: true });
mkdirSync(platformDir, { recursive: true });
writeFileSync(logPath, `MoUI renderer proof backend=${backend} platform=${platform}\n`);
const logs = [logPath];

const log = text => appendFileSync(logPath, `${text}\n`);
const run = args => {
  log(`\n==> ${args.join(" ")}`);
  const result = spawnSync(args[0], args.slice(1), {
    encoding: "utf8",
    env: process.env,
  });
  if (result.stdout) appendFileSync(logPath, result.stdout);
  if (result.stderr) appendFileSync(logPath, result.stderr);
  if (result.status !== 0) {
    if (result.stdout) process.stdout.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
    process.exit(result.status ?? 1);
  }
};

if (backend === "wgpu-native") {
  run(["moon", "test", "moui/render/wgpu", "--target", "native"]);
  run(["moon", "test", "moui/render/wgpu/text_protocol", "--target", "native"]);
  run(["moon", "test", `moui/backend/${platform}/wgpu`, "--target", "native"]);
  log("MoUI renderer proof package tests passed for native WGPU.");
} else {
  const skiaTextEmojiLogPath = `${platformDir}/skia-text-emoji-smoke.log`;
  logs.push(skiaTextEmojiLogPath);
  writeFileSync(
    skiaTextEmojiLogPath,
    [
      `MoUI Skia text/emoji smoke platform=${platform}`,
      "status=failed",
      "missing colorEmojiPixels: requires real Skia high-saturation color emoji pixels or Skia glyph/paragraph evidence.",
      "missing zwjGrapheme: requires single grapheme cluster and no interior caret evidence.",
      "missing bidiLayout: requires visual-order glyph/paragraph evidence.",
      "missing paragraphWrapping: requires line metrics and later-line pixels.",
    ].join("\n") + "\n",
  );
  run(["moon", "test", "moui/render/skia", "--target", "native"]);
  run(["moon", "test", `moui/backend/${platform}/skia`, "--target", "native"]);
  log("MoUI renderer proof package tests passed for native Skia.");
}

log("MoUI renderer proof radialGradient missing: requires true radial center/mid/edge pixel artifact.");
log("MoUI renderer proof transformPixels missing: requires nested transform/clip/layer/filter pixel artifact.");
log("MoUI renderer proof colorEmojiPixels missing: requires real high-saturation emoji raster/glyph evidence.");
log("MoUI renderer proof zwjGrapheme missing: requires single grapheme cluster and no interior caret evidence.");
log("MoUI renderer proof bidiLayout missing: requires visual-order evidence.");
log("MoUI renderer proof paragraphWrapping missing: requires line metrics and later-line pixels.");
log("MoUI renderer proof asyncImageSecondFrame missing: requires late completion, repaint request, and second-frame pixels.");

const recordArgs = [
  "scripts/record-renderer-proof-manifest.mjs",
  "--backend",
  backend,
  "--platform",
  platform,
  "--artifact-name",
  artifactName,
  "--output",
  manifestPath,
];
for (const path of logs) {
  recordArgs.push("--log", path);
}
const record = spawnSync(process.execPath, recordArgs, { encoding: "utf8", env: process.env });
if (record.stdout) process.stdout.write(record.stdout);
if (record.stderr) process.stderr.write(record.stderr);
if (record.status !== 0) process.exit(record.status ?? 1);
