#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { relative, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const usage = () => {
  console.error(`Usage: node scripts/record-macos-platform-runtime-evidence.mjs <manifest.json> [options]

Options:
  --host <description>                  Matching macOS host that produced logs.
  --consumer-command <command>          Showcase or Markdown Editor macOS Skia
                                        command that produced runtime logs.
  --window-evidence-command <command>   Window recorder command to store.
  --runtime-log <path>                  macOS runtime log; may repeat.
  --window-smoke-log <path>             macOS window-fork runtime smoke log;
                                        may repeat.
  --app-runtime-log <path>              Showcase or Markdown Editor macOS Skia
                                        first-frame runtime log; may repeat.
  --note <text>                         Additional platform evidence note; may
                                        repeat.
  --provenance-kind <github-actions|matching-host-artifact>
  --provenance-workflow <name>
  --provenance-job <name>
  --provenance-run-url <url>
  --provenance-run-id <id>
  --provenance-runner <label>
  --provenance-artifact <path>          Provenance artifact; may repeat.
  --provenance-note <text>              Provenance note; may repeat.

The helper validates matching-host macOS platform runtime log markers, requires
the macOS Skia and native IME observations to already be passed in the manifest,
updates only the macOS platform entry to passed, and delegates schema validation
to record-platform-evidence-manifest.mjs.`);
};

const repoRoot = process.cwd();
const [manifestArg, ...args] = process.argv.slice(2);
if (!manifestArg || args.includes("--help") || args.includes("-h")) {
  usage();
  process.exit(manifestArg ? 0 : 2);
}

const manifestPath = resolve(repoRoot, manifestArg);
let host = "";
let consumerCommand = "";
let windowEvidenceCommand =
  ".local_repos/window/scripts/record_moui_evidence.sh macos --status passed";
const runtimeLogs = [];
const windowSmokeLogs = [];
const appRuntimeLogs = [];
const notes = [];
let provenanceKind = "";
let provenanceWorkflow = "";
let provenanceJob = "";
let provenanceRunUrl = "";
let provenanceRunId = "";
let provenanceRunner = "";
const provenanceArtifacts = [];
const provenanceNotes = [];

for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === "--host") {
    host = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--consumer-command") {
    consumerCommand = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--window-evidence-command") {
    windowEvidenceCommand = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--runtime-log") {
    runtimeLogs.push(args[i + 1] ?? "");
    i += 1;
  } else if (arg === "--window-smoke-log") {
    windowSmokeLogs.push(args[i + 1] ?? "");
    i += 1;
  } else if (arg === "--app-runtime-log") {
    appRuntimeLogs.push(args[i + 1] ?? "");
    i += 1;
  } else if (arg === "--note") {
    notes.push(args[i + 1] ?? "");
    i += 1;
  } else if (arg === "--provenance-kind") {
    provenanceKind = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--provenance-workflow") {
    provenanceWorkflow = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--provenance-job") {
    provenanceJob = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--provenance-run-url") {
    provenanceRunUrl = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--provenance-run-id") {
    provenanceRunId = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--provenance-runner") {
    provenanceRunner = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--provenance-artifact") {
    provenanceArtifacts.push(args[i + 1] ?? "");
    i += 1;
  } else if (arg === "--provenance-note") {
    provenanceNotes.push(args[i + 1] ?? "");
    i += 1;
  } else {
    console.error(`Unknown argument: ${arg}`);
    usage();
    process.exit(2);
  }
}

if (!/macOS|Darwin/i.test(host)) {
  console.error("--host must name a matching macOS/Darwin host");
  process.exit(2);
}
if (!consumerCommand.trim()) {
  console.error("--consumer-command is required for passed macOS platform evidence");
  process.exit(2);
}
const normalizedConsumerCommand = consumerCommand.replace(/\\/g, "/");
const consumerApp = normalizedConsumerCommand.includes("examples/markdown_editor/macos_skia")
  ? {
      title: "MoUI Markdown Editor",
      token: "app=markdown-editor",
      label: "Markdown Editor",
    }
  : normalizedConsumerCommand.includes("examples/showcase/macos_skia")
    ? {
        title: "MoUI Showcase",
        token: "app=showcase",
        label: "Showcase",
      }
    : undefined;
if (!consumerApp) {
  console.error(
    "--consumer-command must name examples/showcase/macos_skia or examples/markdown_editor/macos_skia",
  );
  process.exit(2);
}
if (runtimeLogs.length === 0 && (windowSmokeLogs.length === 0 || appRuntimeLogs.length === 0)) {
  console.error("At least one --runtime-log or both --window-smoke-log and --app-runtime-log are required");
  process.exit(2);
}

const readJson = path => {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    console.error(`${path}: failed to read JSON: ${error.message}`);
    process.exit(1);
  }
};

const manifest = readJson(manifestPath);
const macosEntry = manifest.platforms?.find(entry => entry?.name === "macos");
if (!macosEntry) {
  console.error(`${manifestArg}: platforms must include macos`);
  process.exit(1);
}

const nativeImeObservationKeys = [
  "imeCandidateAnchor",
  "imeSurroundingText",
  "imeCompositionVisual",
  "imeCommitDelete",
  "imeCursorUpdate",
  "imeScrollAnchor",
  "imeScaleDprAnchor",
  "imeResizeAnchor",
  "imeMarkdownEditor",
];
const skiaObservationKeys = [
  "providerPreflight",
  "fallbackUnavailable",
  "realRendererSmoke",
  "asyncImageSecondFrame",
  "showcaseFirstFrame",
  "markdownFirstFrame",
];
const platformObservationKeys = [
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
];

if (macosEntry.skiaEvidence?.status !== "passed") {
  console.error("macos.skiaEvidence.status must already be passed before promoting macOS platform runtime evidence");
  process.exit(1);
}
const incompleteSkia = skiaObservationKeys.find(
  key => macosEntry.skiaEvidence?.observations?.[key] !== "yes",
);
if (incompleteSkia) {
  console.error(`macos.skiaEvidence.observations.${incompleteSkia} must already be yes`);
  process.exit(1);
}
const incompleteIme = nativeImeObservationKeys.find(
  key => macosEntry.observations?.[key] !== "yes",
);
if (incompleteIme) {
  console.error(`macos.observations.${incompleteIme} must already be yes`);
  process.exit(1);
}

const normalizeArtifactPath = (path, label = "macOS runtime artifact") => {
  const absolute = resolve(repoRoot, path);
  const relativePath = relative(repoRoot, absolute);
  if (
    !relativePath.startsWith("artifacts/platform-evidence/macos/") ||
    relativePath.includes("..")
  ) {
    console.error(`${label} must stay under artifacts/platform-evidence/macos/: ${path}`);
    process.exit(2);
  }
  if (!existsSync(absolute)) {
    console.error(`${label} does not exist: ${relativePath}`);
    process.exit(1);
  }
  return relativePath;
};

const runtimeArtifacts = runtimeLogs.map(path => normalizeArtifactPath(path));
const windowSmokeArtifacts = windowSmokeLogs.map(path =>
  normalizeArtifactPath(path, "macOS window smoke artifact"),
);
const appRuntimeArtifacts = appRuntimeLogs.map(path =>
  normalizeArtifactPath(path, "macOS app runtime artifact"),
);
const explicitRuntimeText = runtimeArtifacts
  .map(path => readFileSync(resolve(repoRoot, path), "utf8"))
  .join("\n");
const windowSmokeText = windowSmokeArtifacts
  .map(path => readFileSync(resolve(repoRoot, path), "utf8"))
  .join("\n");
const appRuntimeText = appRuntimeArtifacts
  .map(path => readFileSync(resolve(repoRoot, path), "utf8"))
  .join("\n");

const requireSourceMarker = (text, label, marker, description) => {
  const ok = typeof marker === "string" ? text.includes(marker) : marker.test(text);
  if (!ok) {
    console.error(`${label} is missing expected marker: ${description}`);
    process.exit(1);
  }
};
const requireSourceOrder = (text, label, first, second) => {
  const firstIndex = text.indexOf(first);
  const secondIndex = text.indexOf(second);
  if (firstIndex < 0 || secondIndex < 0 || firstIndex >= secondIndex) {
    console.error(`${label} must contain '${first}' before '${second}'`);
    process.exit(1);
  }
};

const derivedRuntimeLines = [];
if (windowSmokeArtifacts.length > 0) {
  requireSourceMarker(
    windowSmokeText,
    "macOS window smoke log",
    /MOUIMacSmoke: surface size=[1-9][0-9]*x[1-9][0-9]* scale=/,
    "MOUIMacSmoke surface size with scale",
  );
  requireSourceMarker(
    windowSmokeText,
    "macOS window smoke log",
    /MOUIMacSmoke: handles window=0x[1-9a-f][0-9a-f]* content_view=0x[1-9a-f][0-9a-f]*/i,
    "non-zero window and content-view handles",
  );
  requireSourceMarker(
    windowSmokeText,
    "macOS window smoke log",
    /MOUIMacSmoke: monitors count=[1-9][0-9]* primary=true current=true/,
    "monitor and current-monitor probe",
  );
  requireSourceMarker(
    windowSmokeText,
    "macOS window smoke log",
    /MOUIMacSmoke: cursor\b/,
    "cursor probe",
  );
  requireSourceMarker(
    windowSmokeText,
    "macOS window smoke log",
    /MOUIMacSmoke: resize requested size=[1-9][0-9]*x[1-9][0-9]*/,
    "requested resize",
  );
  requireSourceMarker(
    windowSmokeText,
    "macOS window smoke log",
    /MOUIMacSmoke: resize size=[1-9][0-9]*x[1-9][0-9]*/,
    "observed resize",
  );
  requireSourceMarker(
    windowSmokeText,
    "macOS window smoke log",
    "MOUIMacSmoke: redraw pre_present_notify",
    "redraw pre_present_notify",
  );
  requireSourceMarker(
    windowSmokeText,
    "macOS window smoke log",
    /MOUIMacSmoke: pointer x=/,
    "pointer input",
  );
  requireSourceMarker(
    windowSmokeText,
    "macOS window smoke log",
    /MOUIMacSmoke: keyboard text=./,
    "keyboard text input",
  );
  requireSourceMarker(
    windowSmokeText,
    "macOS window smoke log",
    /MOUIMacSmoke: ime probe enabled=true hint=true surrounding=true cursor=true updated=true updated_hint=true updated_cursor=true disabled=true/,
    "IME request/update/disable probe",
  );
  requireSourceMarker(
    windowSmokeText,
    "macOS window smoke log",
    "MOUIMacSmoke: ready",
    "ready sentinel",
  );
  requireSourceOrder(
    windowSmokeText,
    "macOS window smoke log",
    "MOUIMacSmoke: destroyed",
    "MOUIMacSmoke: finished",
  );
  if (windowSmokeText.includes("MOUIMacSmoke: failed")) {
    console.error("macOS window smoke log reported failure");
    process.exit(1);
  }
  derivedRuntimeLines.push(
    "MoUI macOS platform window opened passed window-opened",
    "MoUI macOS platform resize redraw passed resize-redraw",
    "MoUI macOS platform representative input passed representative-input",
    "MoUI macOS platform clean exit passed clean-exit",
    "MoUI macOS platform surface passed surface",
    "MoUI macOS platform redraw passed redraw",
    "MoUI macOS platform resize scale passed resize-scale",
    "MoUI macOS platform consumer input passed consumer-input",
    "MoUI macOS platform text input passed text-input",
    "MoUI macOS platform renderer handle passed renderer-handle",
    "MoUI macOS platform monitor cursor passed monitor-cursor",
    "MoUI macOS platform clean shutdown passed clean-shutdown",
  );
}
if (appRuntimeArtifacts.length > 0) {
  requireSourceMarker(
    appRuntimeText,
    "macOS app runtime log",
    new RegExp(
      `macOS renderer presented first frame; exiting by request; title=${consumerApp.title.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`,
    ),
    `first-frame marker with title=${consumerApp.title}`,
  );
  if (/smoke timed out|did not print the expected first-frame marker|runtime smoke failed/i.test(appRuntimeText)) {
    console.error("macOS app runtime log contains a failed first-frame smoke marker");
    process.exit(1);
  }
  derivedRuntimeLines.unshift(
    `MoUI macOS platform runtime matching-host native-app platform=macos renderer=skia ${consumerApp.token}`,
  );
}

const runtimeText = [
  explicitRuntimeText,
  derivedRuntimeLines.join("\n"),
].filter(text => text.trim()).join("\n");

const escapedRegExp = value => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const exactToken = token => new RegExp(`(?:^|\\s)${escapedRegExp(token)}(?=\\s|$)`, "m");
const hasExactToken = (text, token) => exactToken(token).test(text);
const requireMarker = (label, marker) => {
  const ok = typeof marker === "string"
    ? runtimeText.includes(marker)
    : marker.test(runtimeText);
  if (!ok) {
    console.error(`macOS platform runtime log is missing expected marker for ${label}`);
    process.exit(1);
  }
};
const requireToken = (label, token) => {
  if (!hasExactToken(runtimeText, token)) {
    console.error(`macOS platform runtime log is missing expected token for ${label}: ${token}`);
    process.exit(1);
  }
};

requireMarker("common runtime", /MoUI macOS platform runtime/i);
requireToken("matching host", "matching-host");
requireToken("native app", "native-app");
requireToken("platform", "platform=macos");
requireToken("renderer", "renderer=skia");
requireToken(`${consumerApp.label} app`, consumerApp.token);

const observationMarkers = {
  windowOpened: [/MoUI macOS platform window opened passed/i, "window-opened"],
  resizeRedraw: [/MoUI macOS platform resize redraw passed/i, "resize-redraw"],
  representativeInput: [/MoUI macOS platform representative input passed/i, "representative-input"],
  cleanExit: [/MoUI macOS platform clean exit passed/i, "clean-exit"],
  surface: [/MoUI macOS platform surface passed/i, "surface"],
  redraw: [/MoUI macOS platform redraw passed/i, "redraw"],
  resizeScale: [/MoUI macOS platform resize scale passed/i, "resize-scale"],
  consumerInput: [/MoUI macOS platform consumer input passed/i, "consumer-input"],
  textInput: [/MoUI macOS platform text input passed/i, "text-input"],
  rendererHandle: [/MoUI macOS platform renderer handle passed/i, "renderer-handle"],
  monitorCursor: [/MoUI macOS platform monitor cursor passed/i, "monitor-cursor"],
  cleanShutdown: [/MoUI macOS platform clean shutdown passed/i, "clean-shutdown"],
};
for (const [key, [phrase, token]] of Object.entries(observationMarkers)) {
  requireMarker(key, phrase);
  requireToken(key, token);
}

const existingArtifacts = (macosEntry.artifacts ?? []).filter(
  artifact => typeof artifact === "string" && !/\/README\.md$/i.test(artifact),
);
const artifactSet = new Set([...existingArtifacts, ...runtimeArtifacts]);
for (const artifact of windowSmokeArtifacts) {
  artifactSet.add(artifact);
}
for (const artifact of appRuntimeArtifacts) {
  artifactSet.add(artifact);
}
const allArtifacts = [...artifactSet];
const noteSet = new Set([
  ...(macosEntry.notes ?? []).filter(note => typeof note === "string"),
  ...notes,
  "macOS platform runtime evidence was marker-validated by record-macos-platform-runtime-evidence.mjs.",
]);
const allNotes = [...noteSet];

if (!provenanceKind) {
  provenanceKind = process.env.GITHUB_ACTIONS === "true"
    ? "github-actions"
    : "matching-host-artifact";
}
if (provenanceKind !== "github-actions" && provenanceKind !== "matching-host-artifact") {
  console.error("--provenance-kind must be github-actions or matching-host-artifact");
  process.exit(2);
}
if (provenanceKind === "github-actions") {
  const serverUrl = process.env.GITHUB_SERVER_URL ?? "https://github.com";
  const repository = process.env.GITHUB_REPOSITORY ?? "";
  const runId = provenanceRunId || process.env.GITHUB_RUN_ID || "";
  provenanceWorkflow ||= process.env.GITHUB_WORKFLOW || "";
  provenanceJob ||= process.env.GITHUB_JOB || "";
  provenanceRunUrl ||= repository && runId
    ? `${serverUrl}/${repository}/actions/runs/${runId}`
    : "";
  provenanceRunId ||= runId;
  provenanceRunner ||= [
    process.env.RUNNER_NAME,
    process.env.RUNNER_OS,
    process.env.RUNNER_ARCH,
  ].filter(Boolean).join(" ");
}

const provenanceArtifactSet = new Set([
  ...allArtifacts,
  ...provenanceArtifacts,
]);
const provenanceNoteSet = new Set([
  ...provenanceNotes,
  provenanceKind === "github-actions"
    ? "macOS platform runtime evidence came from a successful GitHub Actions matching-host job."
    : "macOS platform runtime evidence came from local matching-host artifacts.",
]);

const recordArgs = [
  "scripts/record-platform-evidence-manifest.mjs",
  relative(repoRoot, manifestPath),
  "macos",
  "--status",
  "passed",
  "--host",
  host,
  "--window-evidence-command",
  windowEvidenceCommand,
  "--consumer-command",
  consumerCommand,
  "--provenance-kind",
  provenanceKind,
  "--provenance-host",
  host,
];
for (const key of platformObservationKeys) {
  recordArgs.push("--set", `${key}=yes`);
}
for (const artifact of allArtifacts) {
  recordArgs.push("--artifact", artifact);
}
for (const note of allNotes) {
  recordArgs.push("--note", note);
}
for (const artifact of provenanceArtifactSet) {
  recordArgs.push("--provenance-artifact", artifact);
}
for (const note of provenanceNoteSet) {
  recordArgs.push("--provenance-note", note);
}
if (provenanceKind === "github-actions") {
  recordArgs.push("--provenance-workflow", provenanceWorkflow);
  recordArgs.push("--provenance-job", provenanceJob);
  recordArgs.push("--provenance-run-url", provenanceRunUrl);
  recordArgs.push("--provenance-run-id", provenanceRunId);
  recordArgs.push("--provenance-runner", provenanceRunner);
}

const result = spawnSync(process.execPath, recordArgs, {
  cwd: repoRoot,
  encoding: "utf8",
});
if (result.stdout) process.stdout.write(result.stdout);
if (result.stderr) process.stderr.write(result.stderr);
if (result.status !== 0) process.exit(result.status ?? 1);
console.log(`macOS platform runtime evidence recorded: ${relative(repoRoot, manifestPath)}`);
