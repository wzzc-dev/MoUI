#!/usr/bin/env node

import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { basename, dirname, join } from "node:path";
import { spawnSync } from "node:child_process";

const usage = () => {
  console.error(`Usage: node scripts/record-platform-evidence-manifest.mjs <manifest.json> <platform> [options]

Platforms:
  web | macos | windows | linux

Options:
  --status <passed|failed|pending>
  --host <description>
  --window-evidence-command <command>
  --consumer-command <command|pending>
  --set <observation=yes|no|pending>   May be repeated.
  --artifact <path>                    May be repeated.
  --note <text>                        May be repeated.
  --web-presentation-manifest <path>   Derive the web entry from a validated
                                       web-runtime-presentation manifest.

The script updates one platform entry in a platform runtime evidence manifest
and then validates that platform with validate-platform-evidence-manifest.mjs.`);
};

const defaultPath = "artifacts/conformance/platform-runtime-evidence.json";
const platforms = new Set(["web", "macos", "windows", "linux"]);
const statuses = new Set(["passed", "failed", "pending"]);
const observationKeys = new Set([
  "windowOpened",
  "resizeRedraw",
  "representativeInput",
  "cleanExit",
  "surface",
  "redraw",
  "resizeScale",
  "consumerInput",
  "textInput",
  "rendererHandle",
  "cleanShutdown",
]);
const observationValues = new Set(["yes", "no", "pending"]);

const args = process.argv.slice(2);
if (args.length < 2 || args.includes("--help") || args.includes("-h")) {
  usage();
  process.exit(args.length < 2 ? 2 : 0);
}

const manifestPath = args[0] || defaultPath;
const platform = args[1];
if (!platforms.has(platform)) {
  console.error(`Unknown platform: ${platform}`);
  usage();
  process.exit(2);
}

let status;
let host;
let windowEvidenceCommand;
let consumerCommand;
const observations = new Map();
const artifacts = [];
const notes = [];
let webPresentationManifest;

for (let i = 2; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === "--status") {
    status = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--host") {
    host = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--window-evidence-command") {
    windowEvidenceCommand = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--consumer-command") {
    consumerCommand = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--set") {
    const assignment = args[i + 1] ?? "";
    i += 1;
    const equalsIndex = assignment.indexOf("=");
    if (equalsIndex <= 0) {
      console.error(`Invalid --set value: ${assignment}`);
      process.exit(2);
    }
    const key = assignment.slice(0, equalsIndex);
    const value = assignment.slice(equalsIndex + 1);
    if (!observationKeys.has(key)) {
      console.error(`Unknown observation key: ${key}`);
      process.exit(2);
    }
    if (!observationValues.has(value)) {
      console.error(`Observation ${key} must be yes, no, or pending; got ${value}`);
      process.exit(2);
    }
    observations.set(key, value);
  } else if (arg === "--artifact") {
    artifacts.push(args[i + 1] ?? "");
    i += 1;
  } else if (arg === "--note") {
    notes.push(args[i + 1] ?? "");
    i += 1;
  } else if (arg === "--web-presentation-manifest") {
    webPresentationManifest = args[i + 1] ?? "";
    i += 1;
  } else {
    console.error(`Unknown argument: ${arg}`);
    usage();
    process.exit(2);
  }
}

if (status && !statuses.has(status)) {
  console.error(`--status must be passed, failed, or pending; got ${status}`);
  process.exit(2);
}

const nonEmpty = (value, label) => {
  if (typeof value !== "string" || value.trim() === "") {
    console.error(`${label} must be a non-empty string`);
    process.exit(2);
  }
};

if (host !== undefined) nonEmpty(host, "--host");
if (windowEvidenceCommand !== undefined) {
  nonEmpty(windowEvidenceCommand, "--window-evidence-command");
}
if (consumerCommand !== undefined) nonEmpty(consumerCommand, "--consumer-command");
artifacts.forEach((artifact, index) => nonEmpty(artifact, `--artifact ${index + 1}`));
notes.forEach((note, index) => nonEmpty(note, `--note ${index + 1}`));
if (webPresentationManifest !== undefined) {
  nonEmpty(webPresentationManifest, "--web-presentation-manifest");
  if (platform !== "web") {
    console.error("--web-presentation-manifest can only update the web platform entry");
    process.exit(2);
  }
  if (
    status !== undefined ||
    host !== undefined ||
    windowEvidenceCommand !== undefined ||
    consumerCommand !== undefined ||
    observations.size > 0 ||
    artifacts.length > 0
  ) {
    console.error(
      "--web-presentation-manifest derives status, host, consumer command, observations, and artifacts; do not combine it with --status, --host, --window-evidence-command, --consumer-command, --set, or --artifact",
    );
    process.exit(2);
  }
}

const validateWebPresentationManifest = path => {
  const validation = spawnSync(
    process.execPath,
    ["scripts/validate-web-runtime-presentation-manifest.mjs", path],
    { encoding: "utf8" },
  );
  if (validation.stdout) process.stdout.write(validation.stdout);
  if (validation.stderr) process.stderr.write(validation.stderr);
  if (validation.status !== 0) {
    process.exit(validation.status ?? 1);
  }
};

const allTargetsObserved = (webManifest, key) =>
  Array.isArray(webManifest.targets) &&
  webManifest.targets.length > 0 &&
  webManifest.targets.every(target => target?.observations?.[key] === "yes");

const copyWebPresentationArtifacts = (webManifest, sourcePath) => {
  const targetDir = "artifacts/platform-evidence/web";
  mkdirSync(targetDir, { recursive: true });
  const manifestArtifact = join(targetDir, "web-runtime-presentation.json");
  writeFileSync(manifestArtifact, `${JSON.stringify(webManifest, null, 2)}\n`);
  const copied = [manifestArtifact];
  for (const target of webManifest.targets ?? []) {
    const source = target?.screenshot?.artifact;
    if (typeof source !== "string" || source.trim() === "" || !existsSync(source)) {
      continue;
    }
    const output = join(targetDir, basename(source));
    copyFileSync(source, output);
    copied.push(output);
  }
  if (existsSync(sourcePath) && sourcePath !== manifestArtifact) {
    // The normalized copy above is the platform artifact; sourcePath stays as
    // the conformance artifact referenced by the browser recorder.
  }
  return copied;
};

const applyWebPresentationEvidence = (entry, path) => {
  validateWebPresentationManifest(path);
  const webManifest = JSON.parse(readFileSync(path, "utf8"));
  const allPassed = webManifest.overallStatus === "passed";
  const surfaceReady =
    allTargetsObserved(webManifest, "webGpuAvailable") &&
    allTargetsObserved(webManifest, "deviceRequested") &&
    allTargetsObserved(webManifest, "canvasCreated") &&
    allTargetsObserved(webManifest, "canvasSized");
  const redrawReady =
    allTargetsObserved(webManifest, "statusRunning") &&
    allTargetsObserved(webManifest, "nonblankScreenshot") &&
    allTargetsObserved(webManifest, "cleanConsole");
  const rendererHandleReady =
    allTargetsObserved(webManifest, "deviceRequested") &&
    allTargetsObserved(webManifest, "wasmStarted") &&
    allTargetsObserved(webManifest, "cleanConsole");

  entry.status = allPassed ? "pending" : "failed";
  entry.host = `Web wasm-gc browser host (${webManifest.browser?.product ?? "unknown browser"})`;
  entry.consumerCommand =
    `node scripts/record-web-runtime-presentation.mjs --base-url ${webManifest.baseUrl} ` +
    `--cdp-url ${webManifest.cdpUrl} --manifest ${path}${allPassed ? " --require-passed" : ""}`;
  entry.observations = {
    ...entry.observations,
    windowOpened: allTargetsObserved(webManifest, "pageLoaded") ? "yes" : "no",
    surface: surfaceReady ? "yes" : "no",
    redraw: redrawReady ? "yes" : "no",
    rendererHandle: rendererHandleReady ? "yes" : "no",
  };
  entry.artifacts = copyWebPresentationArtifacts(webManifest, path);
  entry.notes = [
    allPassed
      ? "Web browser presentation manifest passed; platform entry remains pending until resize/input/shutdown evidence is recorded."
      : "Web browser presentation manifest failed; do not claim passed Web runtime evidence from this browser session.",
    `Web presentation manifest: ${path}`,
    `Browser evidence boundary: ${webManifest.evidenceBoundary}`,
  ];
};

let manifest;
try {
  manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
} catch (error) {
  console.error(`${manifestPath}: failed to read JSON: ${error.message}`);
  process.exit(1);
}

if (!Array.isArray(manifest.platforms)) {
  console.error(`${manifestPath}: field 'platforms' must be an array`);
  process.exit(1);
}

const entry = manifest.platforms.find(item => item && item.name === platform);
if (!entry) {
  console.error(`${manifestPath}: platforms must include '${platform}'`);
  process.exit(1);
}

if (status) entry.status = status;
if (host !== undefined) entry.host = host;
if (windowEvidenceCommand !== undefined) {
  entry.windowEvidenceCommand = windowEvidenceCommand;
}
if (consumerCommand !== undefined) entry.consumerCommand = consumerCommand;

if (!entry.observations || typeof entry.observations !== "object" || Array.isArray(entry.observations)) {
  entry.observations = {};
}

if (webPresentationManifest !== undefined) {
  applyWebPresentationEvidence(entry, webPresentationManifest);
}

for (const [key, value] of observations) {
  entry.observations[key] = value;
}

if (artifacts.length > 0) {
  entry.artifacts = artifacts;
}
if (notes.length > 0) {
  entry.notes = webPresentationManifest !== undefined
    ? [...entry.notes, ...notes]
    : notes;
}

mkdirSync(dirname(manifestPath), { recursive: true });
writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);

const validation = spawnSync(
  process.execPath,
  ["scripts/validate-platform-evidence-manifest.mjs", manifestPath, "--platform", platform],
  { encoding: "utf8" },
);

if (validation.stdout) process.stdout.write(validation.stdout);
if (validation.stderr) process.stderr.write(validation.stderr);
if (validation.status !== 0) {
  process.exit(validation.status ?? 1);
}

console.log(`${manifestPath}: updated ${platform} evidence entry`);
