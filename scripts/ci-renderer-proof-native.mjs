#!/usr/bin/env node

import {
  appendFileSync,
  copyFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";

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
let failureStatus = 0;
const skiaRendererSmokePackage = "moui/tests/skia_renderer_smoke/native";
const skiaRendererSmokeExe = process.platform === "win32"
  ? ".\\_build\\native\\debug\\build\\wzzc-dev\\moui\\tests\\skia_renderer_smoke\\native\\native.exe"
  : "./_build/native/debug/build/wzzc-dev/moui/tests/skia_renderer_smoke/native/native.exe";
const skiaTextEmojiSmokePackage = "moui/tests/skia_text_emoji_smoke/native";
const skiaTextEmojiSmokeExe = process.platform === "win32"
  ? ".\\_build\\native\\debug\\build\\wzzc-dev\\moui\\tests\\skia_text_emoji_smoke\\native\\native.exe"
  : "./_build/native/debug/build/wzzc-dev/moui/tests/skia_text_emoji_smoke/native/native.exe";

const log = text => appendFileSync(logPath, `${text}\n`);

const uniqueExistingDirs = dirs => {
  const seen = new Set();
  const result = [];
  for (const dir of dirs) {
    if (typeof dir !== "string" || dir.trim() === "") continue;
    const resolved = resolve(dir);
    if (seen.has(resolved) || !existsSync(resolved)) continue;
    try {
      if (statSync(resolved).isDirectory()) {
        seen.add(resolved);
        result.push(resolved);
      }
    } catch (_) {
      // Ignore roots that disappear while CI is preparing artifacts.
    }
  }
  return result;
};

const findFileNamed = (root, fileName) => {
  const stack = [root];
  const seen = new Set();
  while (stack.length > 0) {
    const current = stack.pop();
    const resolved = resolve(current);
    if (seen.has(resolved)) continue;
    seen.add(resolved);
    let entries;
    try {
      entries = readdirSync(resolved, { withFileTypes: true });
    } catch (_) {
      continue;
    }
    for (const entry of entries) {
      const fullPath = join(resolved, entry.name);
      if (entry.isFile() && entry.name === fileName) return fullPath;
      if (entry.isDirectory() && entry.name !== ".git" && entry.name !== "_build") {
        stack.push(fullPath);
      }
    }
  }
  return "";
};

const findSkiaIcuDataFile = () => {
  const explicitPath = process.env.MOUI_SKIA_ICUDTL_DAT ?? "";
  if (explicitPath && existsSync(explicitPath)) return resolve(explicitPath);
  const roots = uniqueExistingDirs([
    process.env.MOUI_SKIA_SKIA_ROOT,
    process.env.MOUI_SKIA_SKIA_LIB_DIR,
    "moui_skia/.skia-cache/release",
  ]);
  for (const root of roots) {
    const found = findFileNamed(root, "icudtl.dat");
    if (found) return found;
  }
  return "";
};

const stageSkiaIcuData = destinationDirs => {
  const source = findSkiaIcuDataFile();
  if (!source) {
    log("Skia ICU data file icudtl.dat was not found in configured release roots.");
    return false;
  }
  const uniqueDestinations = [...new Set(destinationDirs.map(dir => resolve(dir)))];
  for (const destinationDir of uniqueDestinations) {
    mkdirSync(destinationDir, { recursive: true });
    const destination = join(destinationDir, "icudtl.dat");
    if (resolve(source) === resolve(destination)) continue;
    copyFileSync(source, destination);
    log(`Staged Skia ICU data: ${destination}`);
  }
  return true;
};

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
    failureStatus ||= result.status ?? 1;
    log(`command failed with status ${result.status ?? 1}: ${args.join(" ")}`);
    return false;
  }
  return true;
};

const runToLog = (args, outputPath) => {
  log(`\n==> ${args.join(" ")}`);
  appendFileSync(outputPath, `\n==> ${args.join(" ")}\n`);
  const result = spawnSync(args[0], args.slice(1), {
    encoding: "utf8",
    env: process.env,
  });
  if (result.stdout) {
    appendFileSync(logPath, result.stdout);
    appendFileSync(outputPath, result.stdout);
  }
  if (result.stderr) {
    appendFileSync(logPath, result.stderr);
    appendFileSync(outputPath, result.stderr);
  }
  if (result.status !== 0) {
    if (result.stdout) process.stdout.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
    failureStatus ||= result.status ?? 1;
    const message = `command failed with status ${result.status ?? 1}: ${args.join(" ")}`;
    log(message);
    appendFileSync(outputPath, `${message}\nstatus=failed\n`);
    return false;
  }
  appendFileSync(outputPath, "status=passed\n");
  return true;
};

if (backend === "wgpu-native") {
  if (run(["moon", "test", "moui/render/wgpu", "--target", "native"]) &&
      run(["moon", "test", "moui/render/wgpu/text_protocol", "--target", "native"]) &&
      run(["moon", "test", `moui/backend/${platform}/wgpu`, "--target", "native"]) &&
      run(["moon", "run", `moui/tests/wgpu_renderer_proof/${platform}`, "--target", "native"])) {
    log("MoUI renderer proof package tests passed for native WGPU.");
  }
} else {
  const skiaRendererLogPath = `${platformDir}/skia-renderer-smoke.log`;
  const skiaTextEmojiLogPath = `${platformDir}/skia-text-emoji-smoke.log`;
  const skiaPackageIcuDirs = [
    "moui/render/skia",
    `moui/backend/${platform}/skia`,
    skiaRendererSmokePackage,
    skiaTextEmojiSmokePackage,
  ];
  const skiaSmokeIcuDirs = [
    ...skiaPackageIcuDirs,
    dirname(skiaRendererSmokeExe),
    dirname(skiaTextEmojiSmokeExe),
  ];
  logs.push(skiaRendererLogPath);
  logs.push(skiaTextEmojiLogPath);
  writeFileSync(
    skiaRendererLogPath,
    [
      `MoUI Skia renderer smoke platform=${platform}`,
    ].join("\n") + "\n",
  );
  writeFileSync(
    skiaTextEmojiLogPath,
    [
      `MoUI Skia text/emoji smoke platform=${platform}`,
    ].join("\n") + "\n",
  );
  let skiaProofOk = true;
  stageSkiaIcuData(skiaPackageIcuDirs);
  if (!run(["moon", "test", "moui/render/skia", "--target", "native"])) skiaProofOk = false;
  if (!run(["moon", "test", `moui/backend/${platform}/skia`, "--target", "native"])) skiaProofOk = false;
  if (!runToLog(["moon", "build", skiaRendererSmokePackage, "--target", "native"], skiaRendererLogPath)) skiaProofOk = false;
  stageSkiaIcuData(skiaSmokeIcuDirs);
  if (!runToLog([skiaRendererSmokeExe], skiaRendererLogPath)) skiaProofOk = false;
  if (!runToLog(["moon", "build", skiaTextEmojiSmokePackage, "--target", "native"], skiaTextEmojiLogPath)) skiaProofOk = false;
  stageSkiaIcuData(skiaSmokeIcuDirs);
  if (!runToLog([skiaTextEmojiSmokeExe], skiaTextEmojiLogPath)) skiaProofOk = false;
  if (skiaProofOk) {
    log("MoUI renderer proof package tests passed for native Skia.");
  } else {
    appendFileSync(
      skiaRendererLogPath,
      "Skia renderer smoke did not complete every proof observation; inspect renderer proof manifest observation statuses.\n",
    );
    appendFileSync(
      skiaTextEmojiLogPath,
      "Skia text/emoji smoke did not complete every proof observation; inspect renderer proof manifest observation statuses.\n",
    );
  }
}

log("MoUI renderer proof radialGradient missing: requires true radial center/mid/edge pixel artifact.");
log("MoUI renderer proof transformPixels missing: requires nested transform/clip/layer/filter pixel artifact.");
log("MoUI renderer proof colorEmojiPixels missing: requires real high-saturation emoji raster/glyph evidence with font/glyph metadata, fallback request character metadata, and matching stable glyph key.");
log("MoUI renderer proof zwjGrapheme missing: requires single grapheme cluster and no interior caret evidence.");
log("MoUI renderer proof bidiLayout missing: requires visual-order evidence.");
log("MoUI renderer proof paragraphWrapping missing: requires line metrics and later-line pixels.");
log("MoUI renderer proof selectionRects missing: requires selection rectangles, line-range, rect geometry, and hit-test evidence.");
log("MoUI renderer proof graphemeEditing missing: requires grapheme boundaries and edit-action evidence.");
log("MoUI renderer proof imeCandidateAnchor missing: requires candidate anchor, surrounding-text, grapheme-boundary, and utf8-offsets evidence.");
log("MoUI renderer proof imeCompositionVisual missing: requires composition range, composition cursor, and preedit pixel evidence.");
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
if (backend === "skia-native") {
  recordArgs.push("--require-passed");
}
for (const path of logs) {
  recordArgs.push("--log", path);
}
const record = spawnSync(process.execPath, recordArgs, { encoding: "utf8", env: process.env });
if (record.stdout) process.stdout.write(record.stdout);
if (record.stderr) process.stderr.write(record.stderr);
if (record.status !== 0) process.exit(record.status ?? 1);
if (failureStatus !== 0) process.exit(failureStatus);
