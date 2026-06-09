#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, "..");

const usage = () => {
  console.error(`Usage: node scripts/record-native-skia-evidence.mjs <manifest.json> <macos|windows|linux> [options]

Options:
  --host <description>                  Matching host that produced the logs.
  --provider-preflight-log <path>       Log proving the platform Skia provider
                                        preflight/package test or build checks.
  --fallback-unavailable-log <path>     Log proving fallback builds fail with
                                        the explicit moui_skia/native unavailable
                                        diagnostic instead of presenting.
  --renderer-smoke-log <path>           Real MoUI Skia renderer pixel smoke log.
  --gpu-renderer-smoke-log <path>       Real MoUI Skia GPU route smoke log.
                                        This proves the opt-in GPU route marker
                                        in addition to the raster smoke markers.
  --async-image-log <path>              Real MoUI Skia async image second-frame
                                        smoke log.
  --showcase-log <path>                 Showcase *_skia first-frame log.
  --gpu-showcase-log <path>             Showcase macOS Skia first-frame log with
                                        explicit Metal GPU route diagnostics.
  --markdown-log <path>                 Markdown Editor *_skia first-frame log.
  --gpu-markdown-log <path>             Markdown Editor macOS Skia first-frame
                                        log with explicit Metal GPU route
                                        diagnostics.
  --note <text>                         Additional Skia evidence note; may repeat.

The helper validates supplied log markers, updates only the native skiaEvidence
block for the selected platform, and leaves the overall platform status as-is.
Use record-platform-evidence-manifest.mjs for full platform runtime evidence.`);
};

const platforms = new Map([
  [
    "macos",
    {
      hostPattern: /(macOS|Darwin)/i,
      firstFrameMarker: "macOS renderer presented first frame; exiting by request",
      providerMarker: [
        /macOS Skia provider preflight|moui\/backend\/macos\/skia|backend\/macos\/skia/i,
        /Total tests:\s*\d+, passed:\s*\d+, failed:\s*0|build (succeeded|finished)|Finished|renderer=ready|can_render=true/i,
      ],
      fallbackMarker: /macOS Skia renderer selected, but moui_skia\/native is unavailable|moui_skia\/native is unavailable/i,
    },
  ],
  [
    "windows",
    {
      hostPattern: /(Windows|MSVC)/i,
      firstFrameMarker: "Windows renderer presented first frame; exiting by request",
      providerMarker: [
        /Windows Skia provider preflight|moui\/backend\/windows\/skia|backend\/windows\/skia|build_windows_msvc\.ps1/i,
        /Total tests:\s*\d+, passed:\s*\d+, failed:\s*0|build (succeeded|finished)|Finished|renderer=ready|can_render=true/i,
      ],
      fallbackMarker: /Windows Skia renderer selected, but moui_skia\/native is unavailable|moui_skia\/native is unavailable/i,
    },
  ],
  [
    "linux",
    {
      hostPattern: /(Linux|Wayland)/i,
      firstFrameMarker: "Linux renderer presented first frame; exiting by request",
      providerMarker: [
        /Linux Skia provider preflight|moui\/backend\/linux\/skia|backend\/linux\/skia/i,
        /Total tests:\s*\d+, passed:\s*\d+, failed:\s*0|build (succeeded|finished)|Finished|renderer=ready|can_render=true/i,
      ],
      fallbackMarker: /Linux Skia renderer selected, but moui_skia\/native is unavailable|moui_skia\/native is unavailable/i,
    },
  ],
]);

const showcaseFirstFrameTitle = "MoUI Showcase";
const markdownFirstFrameTitle = "MoUI Markdown Editor";

const escapeRegExp = value => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

const firstFrameMarkerForTitle = expectedTitle => platform =>
  new RegExp(
    `${escapeRegExp(platform.firstFrameMarker)}[^\\r\\n]*title=${escapeRegExp(expectedTitle)}(?:\\r?\\n|$)`,
  );

const skiaObservationKeys = [
  "providerPreflight",
  "fallbackUnavailable",
  "realRendererSmoke",
  "asyncImageSecondFrame",
  "showcaseFirstFrame",
  "markdownFirstFrame",
];

const logOptions = new Map([
  [
    "--provider-preflight-log",
    {
      observation: "providerPreflight",
      label: "provider preflight log",
      marker: platform => platform.providerMarker,
      markerDescription: "a platform Skia provider identity plus a preflight/test/build pass marker",
    },
  ],
  [
    "--fallback-unavailable-log",
    {
      observation: "fallbackUnavailable",
      label: "fallback unavailable log",
      marker: platform => platform.fallbackMarker,
      markerDescription: "the explicit moui_skia/native unavailable diagnostic",
    },
  ],
  [
    "--renderer-smoke-log",
    {
      observation: "realRendererSmoke",
      label: "renderer smoke log",
      marker: () => "MoUI Skia renderer smoke passed",
      markerDescription: "MoUI Skia renderer smoke passed",
    },
  ],
  [
    "--async-image-log",
    {
      observation: "asyncImageSecondFrame",
      label: "async image second-frame log",
      marker: () => "MoUI Skia async image second-frame smoke passed",
      markerDescription: "MoUI Skia async image second-frame smoke passed",
    },
  ],
  [
    "--showcase-log",
    {
      observation: "showcaseFirstFrame",
      label: "Showcase first-frame log",
      marker: firstFrameMarkerForTitle(showcaseFirstFrameTitle),
      markerDescription: `the platform first-frame marker with title=${showcaseFirstFrameTitle}`,
    },
  ],
  [
    "--markdown-log",
    {
      observation: "markdownFirstFrame",
      label: "Markdown Editor first-frame log",
      marker: firstFrameMarkerForTitle(markdownFirstFrameTitle),
      markerDescription: `the platform first-frame marker with title=${markdownFirstFrameTitle}`,
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
  console.error(`Unknown native Skia platform: ${platformName}`);
  usage();
  process.exit(2);
}

let host = "";
const suppliedLogs = new Map();
const suppliedGpuRendererSmokeLogs = [];
const suppliedGpuShowcaseLogs = [];
const suppliedGpuMarkdownLogs = [];
const notes = [];

for (let i = 2; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === "--host") {
    host = args[i + 1] ?? "";
    i += 1;
  } else if (arg === "--note") {
    notes.push(args[i + 1] ?? "");
    i += 1;
  } else if (logOptions.has(arg)) {
    suppliedLogs.set(arg, args[i + 1] ?? "");
    i += 1;
  } else if (arg === "--gpu-renderer-smoke-log") {
    suppliedGpuRendererSmokeLogs.push(args[i + 1] ?? "");
    i += 1;
  } else if (arg === "--gpu-showcase-log") {
    suppliedGpuShowcaseLogs.push(args[i + 1] ?? "");
    i += 1;
  } else if (arg === "--gpu-markdown-log") {
    suppliedGpuMarkdownLogs.push(args[i + 1] ?? "");
    i += 1;
  } else {
    console.error(`Unknown argument: ${arg}`);
    usage();
    process.exit(2);
  }
}

if (!host.trim()) {
  console.error("--host is required so Skia route evidence names its matching host");
  process.exit(2);
}
if (!platform.hostPattern.test(host)) {
  console.error(`--host must name a matching ${platformName} host; got '${host}'`);
  process.exit(2);
}
if (
  suppliedLogs.size === 0 &&
  suppliedGpuRendererSmokeLogs.length === 0 &&
  suppliedGpuShowcaseLogs.length === 0 &&
  suppliedGpuMarkdownLogs.length === 0
) {
  console.error("At least one Skia evidence log option is required");
  process.exit(2);
}
if (
  platformName !== "macos" &&
  (suppliedGpuRendererSmokeLogs.length > 0 ||
    suppliedGpuShowcaseLogs.length > 0 ||
    suppliedGpuMarkdownLogs.length > 0)
) {
  console.error("Skia GPU route log options currently require the macos platform");
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
  const matched = matcherMatches(content, matcher);
  if (!matched) {
    console.error(`${label} is missing expected marker: ${description}`);
    process.exit(1);
  }
};

const manifest = readJson(manifestPath);
const entry = Array.isArray(manifest.platforms)
  ? manifest.platforms.find(item => item && item.name === platformName)
  : undefined;
if (!entry) {
  console.error(`${manifestPath}: platforms must include '${platformName}'`);
  process.exit(1);
}

const existingSkiaEvidence = entry.skiaEvidence && typeof entry.skiaEvidence === "object"
  ? entry.skiaEvidence
  : {};
const existingObservations = existingSkiaEvidence.observations &&
  typeof existingSkiaEvidence.observations === "object"
  ? existingSkiaEvidence.observations
  : {};
const finalObservations = Object.fromEntries(
  skiaObservationKeys.map(key => [key, existingObservations[key] ?? "pending"]),
);
const artifacts = new Set(Array.isArray(existingSkiaEvidence.artifacts)
  ? existingSkiaEvidence.artifacts.filter(
      artifact => typeof artifact === "string" && !/\/README\.md$/i.test(artifact),
    )
  : []);

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
  assertMarker(content, config.marker(platform), config.label, config.markerDescription);
  finalObservations[config.observation] = "yes";
  artifacts.add(rel);
}

for (const rawPath of suppliedGpuRendererSmokeLogs) {
  if (!rawPath.trim()) {
    console.error("--gpu-renderer-smoke-log requires a non-empty path");
    process.exit(2);
  }
  const { absolute, rel } = normalizeArtifactPath(rawPath);
  const content = readFileSync(absolute, "utf8");
  if (!content.trim()) {
    console.error(`GPU renderer smoke log is empty: ${rawPath}`);
    process.exit(1);
  }
  assertMarker(
    content,
    /MoUI Skia GPU Metal renderer smoke passed.*route=metal-gpu.*surface_gpu=true.*present_count=1.*pixel-markers/,
    "GPU renderer smoke log",
    "MoUI Skia GPU Metal renderer smoke passed with route=metal-gpu, surface_gpu=true, present_count=1, and pixel-markers",
  );
  artifacts.add(rel);
  notes.push(
    "macOS Metal GPU route smoke proved route=metal-gpu, surface_gpu=true, frame presentation, and pixel markers.",
  );
}

const validateGpuFirstFrameLog = (rawPath, label, expectedTitle) => {
  if (!rawPath.trim()) {
    console.error(`${label} requires a non-empty path`);
    process.exit(2);
  }
  const { absolute, rel } = normalizeArtifactPath(rawPath);
  const content = readFileSync(absolute, "utf8");
  if (!content.trim()) {
    console.error(`${label} is empty: ${rawPath}`);
    process.exit(1);
  }
  assertMarker(
    content,
    firstFrameMarkerForTitle(expectedTitle)(platform),
    label,
    `the platform first-frame marker with title=${expectedTitle}`,
  );
  assertMarker(
    content,
    /macOS Skia renderer route diagnostics: surface_route=metal-gpu; surface_gpu=true/,
    label,
    "macOS Skia renderer route diagnostics with surface_route=metal-gpu and surface_gpu=true",
  );
  artifacts.add(rel);
};

for (const rawPath of suppliedGpuShowcaseLogs) {
  validateGpuFirstFrameLog(rawPath, "GPU Showcase first-frame log", showcaseFirstFrameTitle);
  notes.push(
    "macOS Showcase first-frame smoke proved route=metal-gpu and surface_gpu=true before presentation.",
  );
}

for (const rawPath of suppliedGpuMarkdownLogs) {
  validateGpuFirstFrameLog(rawPath, "GPU Markdown Editor first-frame log", markdownFirstFrameTitle);
  notes.push(
    "macOS Markdown Editor first-frame smoke proved route=metal-gpu and surface_gpu=true before presentation.",
  );
}

const skiaStatus = skiaObservationKeys.every(key => finalObservations[key] === "yes")
  ? "passed"
  : "pending";
const defaultNote = skiaStatus === "passed"
  ? `${platformName} native Skia route evidence passed on ${host}; this records provider/fallback/renderer/first-frame Skia evidence only, not full platform-service runtime evidence.`
  : `${platformName} native Skia route evidence is partially recorded on ${host}; omitted Skia observations remain pending and do not prove full platform runtime readiness.`;

const recorderArgs = [
  "scripts/record-platform-evidence-manifest.mjs",
  manifestPath,
  platformName,
  "--host",
  host,
  "--skia-status",
  skiaStatus,
  "--skia-provenance-kind",
  "matching-host-artifact",
  "--skia-provenance-host",
  host,
];

for (const key of skiaObservationKeys) {
  recorderArgs.push("--skia-set", `${key}=${finalObservations[key]}`);
}

for (const artifact of artifacts) {
  recorderArgs.push("--skia-artifact", artifact);
  recorderArgs.push("--skia-provenance-artifact", artifact);
}

recorderArgs.push("--skia-note", defaultNote);
recorderArgs.push("--skia-provenance-note", defaultNote);
for (const note of notes) {
  if (note.trim()) {
    recorderArgs.push("--skia-note", note);
    recorderArgs.push("--skia-provenance-note", note);
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

console.log(`${manifestPath}: recorded ${platformName} native Skia evidence (${skiaStatus})`);
