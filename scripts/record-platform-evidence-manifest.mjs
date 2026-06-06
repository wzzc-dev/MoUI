#!/usr/bin/env node

import { copyFileSync, existsSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
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
  --provenance-kind <github-actions|matching-host-artifact>
  --provenance-host <description>
  --provenance-workflow <name>         Required for github-actions provenance.
  --provenance-job <name>              Required for github-actions provenance.
  --provenance-run-url <url>           Required for github-actions provenance.
  --provenance-run-id <id>
  --provenance-runner <label>          Required for github-actions provenance.
  --provenance-artifact <ref>          May be repeated.
  --provenance-note <text>             May be repeated.
  --web-presentation-manifest <path>   Derive the web entry from a validated
                                       web-runtime-presentation manifest.
  --skia-status <passed|failed|pending>
  --skia-set <observation=yes|no|pending>
                                       Native Skia observations; may be repeated.
  --skia-boundary <text>               Override the Skia evidence boundary note.
  --skia-provider-command <command>    Override/add Skia provider command; may repeat.
  --skia-runtime-smoke-command <command>
                                       Override/add Skia runtime smoke command;
                                       may repeat.
  --skia-artifact <path>               Native Skia artifact; may be repeated.
  --skia-note <text>                   Native Skia note; may be repeated.
  --skia-provenance-kind <github-actions|matching-host-artifact>
  --skia-provenance-host <description>
  --skia-provenance-workflow <name>    Required for github-actions provenance.
  --skia-provenance-job <name>         Required for github-actions provenance.
  --skia-provenance-run-url <url>      Required for github-actions provenance.
  --skia-provenance-run-id <id>
  --skia-provenance-runner <label>     Required for github-actions provenance.
  --skia-provenance-artifact <ref>     May be repeated.
  --skia-provenance-note <text>        May be repeated.

The script updates one platform entry in a platform runtime evidence manifest
and then validates that platform with validate-platform-evidence-manifest.mjs.`);
};

const defaultPath = "artifacts/conformance/platform-runtime-evidence.json";
const platforms = new Set(["web", "macos", "windows", "linux"]);
const nativeSkiaPlatforms = new Set(["macos", "windows", "linux"]);
const statuses = new Set(["passed", "failed", "pending"]);
const provenanceKinds = new Set(["github-actions", "matching-host-artifact"]);
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
  "monitorCursor",
  "cleanShutdown",
]);
const skiaObservationKeys = new Set([
  "providerPreflight",
  "fallbackUnavailable",
  "realRendererSmoke",
  "asyncImageSecondFrame",
  "showcaseFirstFrame",
  "markdownFirstFrame",
]);
const observationValues = new Set(["yes", "no", "pending"]);

const pendingSkiaObservations = () => ({
  providerPreflight: "pending",
  fallbackUnavailable: "pending",
  realRendererSmoke: "pending",
  asyncImageSecondFrame: "pending",
  showcaseFirstFrame: "pending",
  markdownFirstFrame: "pending",
});

const defaultSkiaEvidence = platform => {
  if (platform === "macos") {
    return {
      status: "pending",
      boundary:
        "Provider/preflight evidence proves native Skia package wiring only; runtime smoke evidence must come from MoUI Skia entrypoints on the named macOS host and does not reuse moui_skia dependency evidence.",
      providerCommands: [
        "moon test moui/render/skia --target native",
        "moon test moui/backend/macos/skia --target native",
      ],
      runtimeSmokeCommands: [
        "scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke --smoke-log artifacts/platform-evidence/macos/skia-renderer-smoke.log --showcase-log artifacts/platform-evidence/macos/showcase-macos-skia-first-frame.log --markdown-log artifacts/platform-evidence/macos/markdown-macos-skia-first-frame.log --record-platform-evidence artifacts/conformance/platform-runtime-evidence.json",
      ],
      observations: pendingSkiaObservations(),
      artifacts: ["artifacts/platform-evidence/macos/README.md"],
      notes: [
        "macOS Skia runtime evidence is pending until the real-Skia renderer smoke and both first-frame Skia entrypoint logs are recorded as artifacts.",
      ],
    };
  }

  if (platform === "windows") {
    return {
      status: "pending",
      boundary:
        "Provider/preflight evidence proves native Skia package wiring only; runtime smoke evidence must come from MoUI Skia entrypoints on the named Windows/MSVC host and does not reuse moui_skia dependency evidence.",
      providerCommands: [
        "moon test moui/render/skia --target native",
        "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon test moui/backend/windows/skia --target native }\"",
        "powershell -ExecutionPolicy Bypass -File scripts/windows/build_windows_msvc.ps1 -Package examples/showcase/windows_skia -BuildOnly",
        "powershell -ExecutionPolicy Bypass -File scripts/windows/build_windows_msvc.ps1 -Package examples/markdown_editor/windows_skia -BuildOnly",
      ],
      runtimeSmokeCommands: [
        "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; $env:MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT='1'; moon run examples/showcase/windows_skia --target native }\"",
        "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; $env:MOUI_MARKDOWN_EDITOR_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT='1'; moon run examples/markdown_editor/windows_skia --target native }\"",
      ],
      observations: pendingSkiaObservations(),
      artifacts: ["artifacts/platform-evidence/windows/README.md"],
      notes: [
        "Windows Skia runtime evidence remains matching-host pending until MSVC first-frame Showcase and Markdown Editor logs are recorded.",
      ],
    };
  }

  if (platform === "linux") {
    return {
      status: "pending",
      boundary:
        "Provider/preflight evidence proves native Skia package wiring only; runtime smoke evidence must come from MoUI Skia entrypoints on the named Linux Wayland host and does not reuse moui_skia dependency evidence.",
      providerCommands: [
        "moon test moui/render/skia --target native",
        "moon test moui/backend/linux/skia --target native",
        "moon build examples/showcase/linux_skia --target native",
        "moon build examples/markdown_editor/linux_skia --target native",
      ],
      runtimeSmokeCommands: [
        "MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/showcase/linux_skia --target native",
        "MOUI_MARKDOWN_EDITOR_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/markdown_editor/linux_skia --target native",
      ],
      observations: pendingSkiaObservations(),
      artifacts: ["artifacts/platform-evidence/linux/README.md"],
      notes: [
        "Linux Skia runtime evidence remains matching-host pending until Wayland first-frame Showcase and Markdown Editor logs are recorded with configured real Skia link flags.",
      ],
    };
  }

  return undefined;
};

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
const provenance = {
  artifacts: [],
  notes: [],
};
let webPresentationManifest;
let skiaStatus;
let skiaBoundary;
const skiaObservations = new Map();
const skiaProviderCommands = [];
const skiaRuntimeSmokeCommands = [];
const skiaArtifacts = [];
const skiaNotes = [];
const skiaProvenance = {
  artifacts: [],
  notes: [],
};

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
  } else if (arg === "--provenance-kind") {
    provenance.kind = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--provenance-host") {
    provenance.host = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--provenance-workflow") {
    provenance.workflow = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--provenance-job") {
    provenance.job = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--provenance-run-url") {
    provenance.runUrl = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--provenance-run-id") {
    provenance.runId = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--provenance-runner") {
    provenance.runner = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--provenance-artifact") {
    provenance.artifacts.push(args[i + 1] ?? "");
    i += 1;
  } else if (arg === "--provenance-note") {
    provenance.notes.push(args[i + 1] ?? "");
    i += 1;
  } else if (arg === "--web-presentation-manifest") {
    webPresentationManifest = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--skia-status") {
    skiaStatus = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--skia-set") {
    const assignment = args[i + 1] ?? "";
    i += 1;
    const equalsIndex = assignment.indexOf("=");
    if (equalsIndex <= 0) {
      console.error(`Invalid --skia-set value: ${assignment}`);
      process.exit(2);
    }
    const key = assignment.slice(0, equalsIndex);
    const value = assignment.slice(equalsIndex + 1);
    if (!skiaObservationKeys.has(key)) {
      console.error(`Unknown Skia observation key: ${key}`);
      process.exit(2);
    }
    if (!observationValues.has(value)) {
      console.error(`Skia observation ${key} must be yes, no, or pending; got ${value}`);
      process.exit(2);
    }
    skiaObservations.set(key, value);
  } else if (arg === "--skia-boundary") {
    skiaBoundary = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--skia-provider-command") {
    skiaProviderCommands.push(args[i + 1] ?? "");
    i += 1;
  } else if (arg === "--skia-runtime-smoke-command") {
    skiaRuntimeSmokeCommands.push(args[i + 1] ?? "");
    i += 1;
  } else if (arg === "--skia-artifact") {
    skiaArtifacts.push(args[i + 1] ?? "");
    i += 1;
  } else if (arg === "--skia-note") {
    skiaNotes.push(args[i + 1] ?? "");
    i += 1;
  } else if (arg === "--skia-provenance-kind") {
    skiaProvenance.kind = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--skia-provenance-host") {
    skiaProvenance.host = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--skia-provenance-workflow") {
    skiaProvenance.workflow = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--skia-provenance-job") {
    skiaProvenance.job = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--skia-provenance-run-url") {
    skiaProvenance.runUrl = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--skia-provenance-run-id") {
    skiaProvenance.runId = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--skia-provenance-runner") {
    skiaProvenance.runner = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--skia-provenance-artifact") {
    skiaProvenance.artifacts.push(args[i + 1] ?? "");
    i += 1;
  } else if (arg === "--skia-provenance-note") {
    skiaProvenance.notes.push(args[i + 1] ?? "");
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
if (skiaStatus && !statuses.has(skiaStatus)) {
  console.error(`--skia-status must be passed, failed, or pending; got ${skiaStatus}`);
  process.exit(2);
}
if (provenance.kind && !provenanceKinds.has(provenance.kind)) {
  console.error(`--provenance-kind must be github-actions or matching-host-artifact; got ${provenance.kind}`);
  process.exit(2);
}
if (skiaProvenance.kind && !provenanceKinds.has(skiaProvenance.kind)) {
  console.error(`--skia-provenance-kind must be github-actions or matching-host-artifact; got ${skiaProvenance.kind}`);
  process.exit(2);
}

const hasSkiaUpdate =
  skiaStatus !== undefined ||
  skiaBoundary !== undefined ||
  skiaObservations.size > 0 ||
  skiaProviderCommands.length > 0 ||
  skiaRuntimeSmokeCommands.length > 0 ||
  skiaArtifacts.length > 0 ||
  skiaNotes.length > 0 ||
  skiaProvenance.kind !== undefined ||
  skiaProvenance.host !== undefined ||
  skiaProvenance.workflow !== undefined ||
  skiaProvenance.job !== undefined ||
  skiaProvenance.runUrl !== undefined ||
  skiaProvenance.runId !== undefined ||
  skiaProvenance.runner !== undefined ||
  skiaProvenance.artifacts.length > 0 ||
  skiaProvenance.notes.length > 0;
if (hasSkiaUpdate && !nativeSkiaPlatforms.has(platform)) {
  console.error("Skia evidence options can only update native Skia platform entries: macos, windows, or linux");
  process.exit(2);
}

const nonEmpty = (value, label) => {
  if (typeof value !== "string" || value.trim() === "") {
    console.error(`${label} must be a non-empty string`);
    process.exit(2);
  }
};

const hasProvenanceUpdate = data =>
  data.kind !== undefined ||
  data.host !== undefined ||
  data.workflow !== undefined ||
  data.job !== undefined ||
  data.runUrl !== undefined ||
  data.runId !== undefined ||
  data.runner !== undefined ||
  data.artifacts.length > 0 ||
  data.notes.length > 0;

const validateProvenanceInput = (data, label) => {
  if (!hasProvenanceUpdate(data)) return;
  nonEmpty(data.kind, `${label}-kind`);
  nonEmpty(data.host, `${label}-host`);
  data.artifacts.forEach((artifact, index) => nonEmpty(artifact, `${label}-artifact ${index + 1}`));
  data.notes.forEach((note, index) => nonEmpty(note, `${label}-note ${index + 1}`));
  if (data.artifacts.length === 0) {
    console.error(`${label}-artifact is required when provenance is recorded`);
    process.exit(2);
  }
  if (data.notes.length === 0) {
    console.error(`${label}-note is required when provenance is recorded`);
    process.exit(2);
  }
  if (data.kind === "github-actions") {
    nonEmpty(data.workflow, `${label}-workflow`);
    nonEmpty(data.job, `${label}-job`);
    nonEmpty(data.runUrl, `${label}-run-url`);
    nonEmpty(data.runner, `${label}-runner`);
    if (!/^https:\/\/github\.com\/.+\/.+\/actions\/runs\/\d+/.test(data.runUrl)) {
      console.error(`${label}-run-url must be a GitHub Actions run URL`);
      process.exit(2);
    }
    if (data.runId !== undefined) nonEmpty(data.runId, `${label}-run-id`);
  }
};

const buildProvenance = data => {
  if (!hasProvenanceUpdate(data)) return undefined;
  const result = {
    kind: data.kind,
    host: data.host,
    artifacts: data.artifacts,
    notes: data.notes,
  };
  if (data.workflow !== undefined) result.workflow = data.workflow;
  if (data.job !== undefined) result.job = data.job;
  if (data.runUrl !== undefined) result.runUrl = data.runUrl;
  if (data.runId !== undefined) result.runId = data.runId;
  if (data.runner !== undefined) result.runner = data.runner;
  return result;
};

if (host !== undefined) nonEmpty(host, "--host");
if (windowEvidenceCommand !== undefined) {
  nonEmpty(windowEvidenceCommand, "--window-evidence-command");
}
if (consumerCommand !== undefined) nonEmpty(consumerCommand, "--consumer-command");
artifacts.forEach((artifact, index) => nonEmpty(artifact, `--artifact ${index + 1}`));
notes.forEach((note, index) => nonEmpty(note, `--note ${index + 1}`));
validateProvenanceInput(provenance, "--provenance");
if (skiaBoundary !== undefined) nonEmpty(skiaBoundary, "--skia-boundary");
skiaProviderCommands.forEach((command, index) => nonEmpty(command, `--skia-provider-command ${index + 1}`));
skiaRuntimeSmokeCommands.forEach((command, index) => nonEmpty(command, `--skia-runtime-smoke-command ${index + 1}`));
skiaArtifacts.forEach((artifact, index) => nonEmpty(artifact, `--skia-artifact ${index + 1}`));
skiaNotes.forEach((note, index) => nonEmpty(note, `--skia-note ${index + 1}`));
validateProvenanceInput(skiaProvenance, "--skia-provenance");
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
    artifacts.length > 0 ||
    hasProvenanceUpdate(provenance) ||
    hasSkiaUpdate
  ) {
    console.error(
      "--web-presentation-manifest derives status, host, consumer command, observations, and artifacts; do not combine it with --status, --host, --window-evidence-command, --consumer-command, --set, --artifact, or Skia evidence options",
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

const webPlatformObservations = webManifest => {
  const observations = webManifest.platformObservations;
  if (observations && typeof observations === "object" && !Array.isArray(observations)) {
    return observations;
  }
  return {
    windowOpened: allTargetsObserved(webManifest, "pageLoaded") ? "yes" : "no",
    resizeRedraw: "pending",
    representativeInput: "pending",
    cleanExit: "pending",
    surface:
      allTargetsObserved(webManifest, "webGpuAvailable") &&
      allTargetsObserved(webManifest, "deviceRequested") &&
      allTargetsObserved(webManifest, "canvasCreated") &&
      allTargetsObserved(webManifest, "canvasSized")
        ? "yes"
        : "no",
    redraw:
      allTargetsObserved(webManifest, "statusRunning") &&
      allTargetsObserved(webManifest, "nonblankScreenshot") &&
      allTargetsObserved(webManifest, "cleanConsole")
        ? "yes"
        : "no",
    resizeScale: "pending",
    consumerInput: "pending",
    textInput: "pending",
    rendererHandle:
      allTargetsObserved(webManifest, "deviceRequested") &&
      allTargetsObserved(webManifest, "wasmStarted") &&
      allTargetsObserved(webManifest, "cleanConsole")
        ? "yes"
        : "no",
    monitorCursor: "pending",
    cleanShutdown: "pending",
  };
};

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

const githubActionsProvenanceForWeb = (entry, artifacts) => {
  const env = process.env;
  if (env.GITHUB_ACTIONS !== "true") {
    return undefined;
  }

  const serverUrl = env.GITHUB_SERVER_URL || "https://github.com";
  const repository = env.GITHUB_REPOSITORY || "";
  const runId = env.GITHUB_RUN_ID || "";
  const workflow = env.GITHUB_WORKFLOW || "";
  const job = env.GITHUB_JOB || "";
  const runner = env.RUNNER_NAME || env.RUNNER_OS || env.RUNNER_ARCH || "";
  if (!repository || !runId || !workflow || !job || !runner) {
    return undefined;
  }

  return {
    kind: "github-actions",
    host: entry.host,
    workflow,
    job,
    runUrl: `${serverUrl}/${repository}/actions/runs/${runId}`,
    runId,
    runner,
    artifacts,
    notes: [
      "Web platform evidence was derived from a browser presentation manifest produced by GitHub Actions.",
      `GitHub Actions job ${job} in workflow ${workflow}.`,
    ],
  };
};

const matchingHostWebProvenance = (entry, path) => ({
  kind: "matching-host-artifact",
  host: entry.host,
  artifacts: entry.artifacts,
  notes: [
    "Web platform evidence was derived from the browser presentation manifest artifact.",
    `Source manifest: ${path}`,
  ],
});

const applyWebPresentationEvidence = (entry, path) => {
  validateWebPresentationManifest(path);
  const webManifest = JSON.parse(readFileSync(path, "utf8"));
  const allPassed = webManifest.overallStatus === "passed";
  const platformObservations = webPlatformObservations(webManifest);
  const browserObservablePlatformObservationsPassed = Object.entries(platformObservations)
    .filter(([key]) => key !== "monitorCursor")
    .every(([, value]) => value === "yes");

  entry.status = allPassed && browserObservablePlatformObservationsPassed ? "passed" : "failed";
  const webEvidencePassed = allPassed && browserObservablePlatformObservationsPassed;
  entry.host = `Web wasm-gc browser host (${webManifest.browser?.product ?? "unknown browser"})`;
  entry.consumerCommand =
    `node scripts/record-web-runtime-presentation.mjs --base-url ${webManifest.baseUrl} ` +
    `--cdp-url ${webManifest.cdpUrl} --manifest ${path}${allPassed ? " --require-passed" : ""}`;
  entry.observations = {
    ...entry.observations,
    ...platformObservations,
  };
  entry.artifacts = copyWebPresentationArtifacts(webManifest, path);
  entry.evidenceProvenance =
    githubActionsProvenanceForWeb(entry, entry.artifacts) ??
    matchingHostWebProvenance(entry, path);
  entry.notes = [
    webEvidencePassed
      ? "Web browser presentation manifest passed with resize, input, text-input, and clean-shutdown observations; monitor/cursor remains pending because CDP evidence is browser-local."
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

if (![1, 2].includes(manifest.schemaVersion)) {
  console.error(`${manifestPath}: schemaVersion must be 1 or 2`);
  process.exit(1);
}

manifest.schemaVersion = 2;
for (const platformEntry of manifest.platforms) {
  if (!platformEntry || typeof platformEntry !== "object" || Array.isArray(platformEntry)) {
    continue;
  }
  if (!platformEntry.observations || typeof platformEntry.observations !== "object" || Array.isArray(platformEntry.observations)) {
    platformEntry.observations = {};
  }
  if (platformEntry.observations.monitorCursor === undefined) {
    platformEntry.observations.monitorCursor = "pending";
  }
  if (nativeSkiaPlatforms.has(platformEntry.name)) {
    if (!platformEntry.skiaEvidence || typeof platformEntry.skiaEvidence !== "object" || Array.isArray(platformEntry.skiaEvidence)) {
      platformEntry.skiaEvidence = defaultSkiaEvidence(platformEntry.name);
    }
    if (!platformEntry.skiaEvidence.observations || typeof platformEntry.skiaEvidence.observations !== "object" || Array.isArray(platformEntry.skiaEvidence.observations)) {
      platformEntry.skiaEvidence.observations = {};
    }
    for (const [key, value] of Object.entries(pendingSkiaObservations())) {
      if (platformEntry.skiaEvidence.observations[key] === undefined) {
        platformEntry.skiaEvidence.observations[key] = value;
      }
    }
  }
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
const provenanceRecord = buildProvenance(provenance);
if (provenanceRecord !== undefined) {
  entry.evidenceProvenance = provenanceRecord;
}

if (!entry.observations || typeof entry.observations !== "object" || Array.isArray(entry.observations)) {
  entry.observations = {};
}

if (webPresentationManifest !== undefined) {
  applyWebPresentationEvidence(entry, webPresentationManifest);
}

for (const [key, value] of observations) {
  entry.observations[key] = value;
}

if (nativeSkiaPlatforms.has(platform)) {
  if (!entry.skiaEvidence || typeof entry.skiaEvidence !== "object" || Array.isArray(entry.skiaEvidence)) {
    entry.skiaEvidence = defaultSkiaEvidence(platform);
  }
  if (!entry.skiaEvidence.observations || typeof entry.skiaEvidence.observations !== "object" || Array.isArray(entry.skiaEvidence.observations)) {
    entry.skiaEvidence.observations = pendingSkiaObservations();
  }
  for (const [key, value] of Object.entries(pendingSkiaObservations())) {
    if (entry.skiaEvidence.observations[key] === undefined) {
      entry.skiaEvidence.observations[key] = value;
    }
  }
  if (skiaStatus !== undefined) entry.skiaEvidence.status = skiaStatus;
  if (skiaBoundary !== undefined) entry.skiaEvidence.boundary = skiaBoundary;
  if (skiaProviderCommands.length > 0) {
    entry.skiaEvidence.providerCommands = skiaProviderCommands;
  }
  if (skiaRuntimeSmokeCommands.length > 0) {
    entry.skiaEvidence.runtimeSmokeCommands = skiaRuntimeSmokeCommands;
  }
  for (const [key, value] of skiaObservations) {
    entry.skiaEvidence.observations[key] = value;
  }
  if (skiaArtifacts.length > 0) {
    entry.skiaEvidence.artifacts = skiaArtifacts;
  }
  if (skiaNotes.length > 0) {
    entry.skiaEvidence.notes = skiaNotes;
  }
  const skiaProvenanceRecord = buildProvenance(skiaProvenance);
  if (skiaProvenanceRecord !== undefined) {
    entry.skiaEvidence.evidenceProvenance = skiaProvenanceRecord;
  }
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
const pendingManifestPath = join(
  dirname(manifestPath),
  `.${basename(manifestPath)}.${process.pid}.tmp`,
);
writeFileSync(pendingManifestPath, `${JSON.stringify(manifest, null, 2)}\n`);

const validation = spawnSync(
  process.execPath,
  ["scripts/validate-platform-evidence-manifest.mjs", pendingManifestPath, "--platform", platform],
  { encoding: "utf8" },
);

if (validation.stdout) process.stdout.write(validation.stdout);
if (validation.stderr) process.stderr.write(validation.stderr);
if (validation.status !== 0) {
  rmSync(pendingManifestPath, { force: true });
  process.exit(validation.status ?? 1);
}

renameSync(pendingManifestPath, manifestPath);
console.log(`${manifestPath}: updated ${platform} evidence entry`);
