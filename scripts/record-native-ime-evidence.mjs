#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, "..");

const usage = () => {
  console.error(`Usage: node scripts/record-native-ime-evidence.mjs <manifest.json> <macos|windows|linux> [options]

Options:
  --host <description>                  Matching host that produced the logs.
  --consumer-command <command>          Showcase or Markdown Editor native Skia
                                        command that produced the IME logs.
  --candidate-anchor-log <path>         Log proving IME candidate anchor caret
                                        geometry plus surrounding text.
  --surrounding-text-log <path>         Log proving grapheme-aware UTF-8
                                        surrounding text offsets.
  --composition-visual-log <path>       Log proving composition range, cursor,
                                        underline, and preedit visual pixels.
  --commit-delete-log <path>            Log proving IME commit and delete flows.
  --cursor-update-log <path>            Log proving IME cursor-area updates.
  --scroll-anchor-log <path>            Log proving candidate anchor after
                                        scrolling.
  --scale-dpr-anchor-log <path>         Log proving candidate anchor after
                                        scale/DPR changes.
  --resize-anchor-log <path>            Log proving candidate anchor after
                                        window resize.
  --markdown-log <path>                 Markdown Editor native Skia IME dogfood
                                        log.
  --note <text>                         Additional IME evidence note; may repeat.

The helper validates supplied matching-host log markers, updates native IME
observations in the selected platform entry, and leaves the broader platform
status unchanged. Every supplied log must also include common runtime markers:
MoUI native IME runtime, matching-host, native-app, renderer=skia, an app
marker matching the consumer command, and a platform-protocol marker such as
platform-protocol=macos-marked-text, platform-protocol=windows-ime, or
platform-protocol=wayland-text-input. Use record-platform-evidence-manifest.mjs
for full platform runtime evidence promotion.`);
};

const platforms = new Map([
  [
    "macos",
    {
      hostPattern: /(macOS|Darwin)/i,
      protocolMarker: /platform-protocol=(macos-marked-text|marked-text|nstextinputclient)/i,
      protocolDescription:
        "platform-protocol=macos-marked-text, platform-protocol=marked-text, or platform-protocol=NSTextInputClient",
    },
  ],
  [
    "windows",
    {
      hostPattern: /(Windows|MSVC)/i,
      protocolMarker: /platform-protocol=(windows-ime|imm|tsf)/i,
      protocolDescription:
        "platform-protocol=windows-ime, platform-protocol=imm, or platform-protocol=tsf",
    },
  ],
  [
    "linux",
    {
      hostPattern: /(Linux|Wayland)/i,
      protocolMarker: /platform-protocol=(wayland-text-input|wayland-ime)/i,
      protocolDescription:
        "platform-protocol=wayland-text-input or platform-protocol=wayland-ime",
    },
  ],
]);

const imeObservationKeys = [
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

const logOptions = new Map([
  [
    "--candidate-anchor-log",
    {
      observation: "imeCandidateAnchor",
      label: "candidate anchor log",
      marker: [
        /MoUI native IME candidate anchor passed/i,
        /candidate-anchor/i,
        /candidate-window/i,
        /caret-rect/i,
        /surrounding-text/i,
      ],
      markerDescription:
        "MoUI native IME candidate anchor passed with candidate-anchor, candidate-window, caret-rect, and surrounding-text markers",
    },
  ],
  [
    "--surrounding-text-log",
    {
      observation: "imeSurroundingText",
      label: "surrounding text log",
      marker: [
        /MoUI native IME surrounding text passed/i,
        /surrounding-text/i,
        /selection-anchor/i,
        /utf-?8-offsets/i,
        /grapheme/i,
      ],
      markerDescription:
        "MoUI native IME surrounding text passed with surrounding-text, selection-anchor, UTF-8 offsets, and grapheme markers",
    },
  ],
  [
    "--composition-visual-log",
    {
      observation: "imeCompositionVisual",
      label: "composition visual log",
      marker: [
        /MoUI native IME composition visual passed/i,
        /composition-range/i,
        /composition-cursor/i,
        /preedit-underline/i,
        /preedit-pixels/i,
        /selection-highlight/i,
      ],
      markerDescription:
        "MoUI native IME composition visual passed with composition-range, composition-cursor, preedit-underline, preedit-pixels, and selection-highlight markers",
    },
  ],
  [
    "--commit-delete-log",
    {
      observation: "imeCommitDelete",
      label: "commit/delete log",
      marker: [
        /MoUI native IME commit delete passed/i,
        /commit/i,
        /delete/i,
        /selection-replacement/i,
      ],
      markerDescription:
        "MoUI native IME commit delete passed with commit, delete, and selection-replacement markers",
    },
  ],
  [
    "--cursor-update-log",
    {
      observation: "imeCursorUpdate",
      label: "cursor update log",
      marker: [
        /MoUI native IME cursor update passed/i,
        /cursor-area/i,
        /cursor-update/i,
        /caret-rect/i,
      ],
      markerDescription:
        "MoUI native IME cursor update passed with cursor-area, cursor-update, and caret-rect markers",
    },
  ],
  [
    "--scroll-anchor-log",
    {
      observation: "imeScrollAnchor",
      label: "scroll anchor log",
      marker: [
        /MoUI native IME scroll anchor passed/i,
        /scroll/i,
        /candidate-anchor/i,
        /candidate-window/i,
      ],
      markerDescription:
        "MoUI native IME scroll anchor passed with scroll, candidate-anchor, and candidate-window markers",
    },
  ],
  [
    "--scale-dpr-anchor-log",
    {
      observation: "imeScaleDprAnchor",
      label: "scale/DPR anchor log",
      marker: [
        /MoUI native IME scale DPR anchor passed/i,
        /scale/i,
        /dpr/i,
        /candidate-anchor/i,
        /candidate-window/i,
      ],
      markerDescription:
        "MoUI native IME scale DPR anchor passed with scale, DPR, candidate-anchor, and candidate-window markers",
    },
  ],
  [
    "--resize-anchor-log",
    {
      observation: "imeResizeAnchor",
      label: "resize anchor log",
      marker: [
        /MoUI native IME resize anchor passed/i,
        /resize/i,
        /candidate-anchor/i,
        /candidate-window/i,
      ],
      markerDescription:
        "MoUI native IME resize anchor passed with resize, candidate-anchor, and candidate-window markers",
    },
  ],
  [
    "--markdown-log",
    {
      observation: "imeMarkdownEditor",
      label: "Markdown Editor IME log",
      marker: [
        /MoUI native IME Markdown Editor passed/i,
        /markdown-editor/i,
        /composition/i,
        /candidate-anchor/i,
        /candidate-window/i,
        /selection-replacement/i,
        /source-mapping/i,
      ],
      markerDescription:
        "MoUI native IME Markdown Editor passed with markdown-editor, composition, candidate-anchor, candidate-window, selection-replacement, and source-mapping markers",
    },
  ],
]);

const args = process.argv.slice(2);
if (args.length < 2 || args.includes("--help") || args.includes("-h")) {
  usage();
  process.exit(args.length < 2 ? 2 : 0);
}

const manifestPath = resolve(process.cwd(), args[0]);
const platformName = args[1];
const platform = platforms.get(platformName);
if (!platform) {
  console.error(`Unknown native IME platform: ${platformName}`);
  usage();
  process.exit(2);
}

let host = "";
let consumerCommand = "";
const suppliedLogs = new Map();
const notes = [];

for (let i = 2; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === "--host") {
    host = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--consumer-command") {
    consumerCommand = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--note") {
    notes.push(args[i + 1] ?? "");
    i += 1;
  } else if (logOptions.has(arg)) {
    suppliedLogs.set(arg, args[i + 1] ?? "");
    i += 1;
  } else {
    console.error(`Unknown argument: ${arg}`);
    usage();
    process.exit(2);
  }
}

if (!host.trim()) {
  console.error("--host is required so IME runtime evidence names its matching host");
  process.exit(2);
}
if (!platform.hostPattern.test(host)) {
  console.error(`--host must name a matching ${platformName} host; got '${host}'`);
  process.exit(2);
}
if (!consumerCommand.trim()) {
  console.error("--consumer-command is required so IME observations name the native app run");
  process.exit(2);
}
const normalizedConsumerCommand = consumerCommand.replace(/\\/g, "/");
const showcaseTarget = `examples/showcase/${platformName}_skia`;
const markdownTarget = `examples/markdown_editor/${platformName}_skia`;
const consumerNamesNativeSkiaApp =
  normalizedConsumerCommand.includes(showcaseTarget) ||
  normalizedConsumerCommand.includes(markdownTarget);
if (!consumerNamesNativeSkiaApp) {
  console.error(
    `--consumer-command must name ${showcaseTarget} or ${markdownTarget}; got '${consumerCommand}'`,
  );
  process.exit(2);
}
if (
  suppliedLogs.has("--markdown-log") &&
  !normalizedConsumerCommand.includes(markdownTarget)
) {
  console.error(`--markdown-log requires --consumer-command to name ${markdownTarget}`);
  process.exit(2);
}
const expectedConsumerApp = normalizedConsumerCommand.includes(markdownTarget)
  ? {
      marker: /app=markdown-editor/i,
      description: "app=markdown-editor",
    }
  : {
      marker: /app=showcase/i,
      description: "app=showcase",
    };
if (suppliedLogs.size === 0) {
  console.error("At least one native IME evidence log option is required");
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

const normalizeArtifactPath = path => {
  const absolute = resolve(repoRoot, path);
  const rel = relative(repoRoot, absolute).replace(/\\/g, "/");
  if (rel.startsWith("..") || resolve(repoRoot, rel) !== absolute) {
    console.error(`artifact log must be inside the repository: ${path}`);
    process.exit(2);
  }
  const expectedPrefix = `artifacts/platform-evidence/${platformName}/`;
  if (!rel.startsWith(expectedPrefix)) {
    console.error(`artifact log must stay under ${expectedPrefix}: ${path}`);
    process.exit(2);
  }
  if (!existsSync(absolute)) {
    console.error(`artifact log does not exist: ${path}`);
    process.exit(1);
  }
  return { absolute, rel };
};

const matcherMatches = (content, matcher) => {
  if (typeof matcher === "string") {
    return content.includes(matcher);
  }
  if (Array.isArray(matcher)) {
    return matcher.every(item => matcherMatches(content, item));
  }
  return matcher.test(content);
};

const assertMarker = (content, matcher, label, description) => {
  if (!matcherMatches(content, matcher)) {
    console.error(`${label} is missing expected marker: ${description}`);
    process.exit(1);
  }
};

const assertRuntimeMarkers = (content, label) => {
  assertMarker(
    content,
    [
      /MoUI native IME runtime/i,
      /matching-host/i,
      /native-app/i,
      /renderer=skia/i,
      expectedConsumerApp.marker,
      platform.protocolMarker,
    ],
    label,
    `MoUI native IME runtime, matching-host, native-app, renderer=skia, ${expectedConsumerApp.description}, and ${platform.protocolDescription} markers`,
  );
};

const manifest = readJson(manifestPath);
const entry = Array.isArray(manifest.platforms)
  ? manifest.platforms.find(item => item && item.name === platformName)
  : undefined;
if (!entry) {
  console.error(`${manifestPath}: platforms must include '${platformName}'`);
  process.exit(1);
}

const existingObservations = entry.observations && typeof entry.observations === "object"
  ? entry.observations
  : {};
const finalObservations = Object.fromEntries(
  imeObservationKeys.map(key => [key, existingObservations[key] ?? "pending"]),
);
const artifacts = new Set(Array.isArray(entry.artifacts) ? entry.artifacts : []);
const provenanceArtifacts = new Set();

for (const [option, rawPath] of suppliedLogs) {
  const config = logOptions.get(option);
  if (!rawPath.trim()) {
    console.error(`${option} requires a non-empty path`);
    process.exit(2);
  }
  const { absolute, rel } = normalizeArtifactPath(rawPath);
  const content = readFileSync(absolute, "utf8");
  if (!content.trim()) {
    console.error(`${config.label} is empty: ${rawPath}`);
    process.exit(1);
  }
  assertRuntimeMarkers(content, config.label);
  assertMarker(content, config.marker, config.label, config.markerDescription);
  finalObservations[config.observation] = "yes";
  artifacts.add(rel);
  provenanceArtifacts.add(rel);
}

const imeStatus = imeObservationKeys.every(key => finalObservations[key] === "yes")
  ? "complete"
  : "partial";
const defaultNote = imeStatus === "complete"
  ? `${platformName} native IME runtime evidence is fully recorded on ${host}; this still does not prove full platform readiness without the other platform observations and Skia route evidence.`
  : `${platformName} native IME runtime evidence is partially recorded on ${host}; omitted IME observations remain pending and do not prove native IME readiness.`;

const recorderArgs = [
  "scripts/record-platform-evidence-manifest.mjs",
  manifestPath,
  platformName,
  "--host",
  host,
  "--consumer-command",
  consumerCommand,
  "--provenance-kind",
  "matching-host-artifact",
  "--provenance-host",
  host,
];

for (const key of imeObservationKeys) {
  recorderArgs.push("--set", `${key}=${finalObservations[key]}`);
}

for (const artifact of artifacts) {
  recorderArgs.push("--artifact", artifact);
}
for (const artifact of provenanceArtifacts) {
  recorderArgs.push("--provenance-artifact", artifact);
}

recorderArgs.push("--note", defaultNote);
recorderArgs.push("--provenance-note", defaultNote);
for (const note of notes) {
  if (note.trim()) {
    recorderArgs.push("--note", note);
    recorderArgs.push("--provenance-note", note);
  }
}

const result = spawnSync(process.execPath, recorderArgs, {
  cwd: repoRoot,
  encoding: "utf8",
});
if (result.stdout) process.stdout.write(result.stdout);
if (result.stderr) process.stderr.write(result.stderr);
if (result.status !== 0) {
  process.exit(result.status ?? 1);
}

console.log(`${manifestPath}: recorded ${platformName} native IME evidence (${imeStatus})`);
