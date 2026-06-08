#!/usr/bin/env node

import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const tmp = mkdtempSync(join(tmpdir(), "moui-platform-evidence-record-"));
const recorder = "scripts/record-platform-evidence-manifest.mjs";
const githubEnvKeys = [
  "GITHUB_ACTIONS",
  "GITHUB_SERVER_URL",
  "GITHUB_REPOSITORY",
  "GITHUB_RUN_ID",
  "GITHUB_WORKFLOW",
  "GITHUB_JOB",
  "RUNNER_NAME",
  "RUNNER_OS",
  "RUNNER_ARCH",
];

const withoutGithubEnv = () => {
  const env = { ...process.env };
  for (const key of githubEnvKeys) {
    delete env[key];
  }
  return env;
};

const pendingObservations = {
  windowOpened: "pending",
  resizeRedraw: "pending",
  representativeInput: "pending",
  cleanExit: "pending",
  surface: "pending",
  redraw: "pending",
  resizeScale: "pending",
  consumerInput: "pending",
  textInput: "pending",
  rendererHandle: "pending",
  monitorCursor: "pending",
  cleanShutdown: "pending",
};

const webPresentationObservationKeys = [
  "pageLoaded",
  "webGpuAvailable",
  "adapterRequested",
  "deviceRequested",
  "wasmStarted",
  "statusRunning",
  "canvasCreated",
  "canvasSized",
  "nonblankScreenshot",
  "cleanConsole",
  "resizeEvent",
  "resizedCanvas",
  "pointerInput",
  "keyboardInput",
  "textInput",
  "radialGradient",
  "transformPixels",
  "colorEmojiPixels",
  "zwjGrapheme",
  "bidiLayout",
  "paragraphWrapping",
  "selectionRects",
  "graphemeEditing",
  "imeCandidateAnchor",
  "imeCompositionVisual",
  "asyncImageSecondFrame",
  "targetClosed",
];

const webPlatformObservationKeys = Object.keys(pendingObservations).filter(
  key => key !== "monitorCursor",
);

const webPresentationObservations = value =>
  Object.fromEntries(webPresentationObservationKeys.map(key => [key, value]));

const webRendererProofEvidence = {
  radialGradient: ["center-mid-edge-pixels", "shader-payload"],
  colorEmojiPixels: ["high-saturation-pixels", "glyph-or-raster", "font-metadata", "glyph-metadata"],
  zwjGrapheme: ["single-grapheme-cluster", "no-interior-caret"],
  bidiLayout: ["visual-order"],
  paragraphWrapping: ["line-metrics", "later-line-pixels"],
  selectionRects: ["selection-rects", "line-range"],
  graphemeEditing: ["grapheme-boundaries", "edit-actions"],
  imeCandidateAnchor: ["candidate-anchor", "surrounding-text"],
  imeCompositionVisual: ["composition-range", "preedit-pixels"],
  asyncImageSecondFrame: ["late-completion", "repaint-request", "second-frame-pixels"],
};

const webRendererProof = (name, status, key) => {
  const required = name === "showcase-web-wasm";
  const passed = required && status === "passed";
  const base = {
    required,
    passed,
    evidence: passed ? webRendererProofEvidence[key] : [],
    matchedMarkers: passed ? webRendererProofEvidence[key].length : 0,
  };
  if (!passed) return base;
  if (key === "colorEmojiPixels") {
    return {
      ...base,
      glyphHighSaturationPixels: 42,
      glyphAlphaPixels: 120,
      metadata: {
        font: {
          family: "system-ui, emoji",
          source: "browser-canvas",
          textSystem: "webgpu-wasm",
        },
        glyph: {
          format: "rgba",
          glyphCount: 1,
          clusterCount: 1,
          highSaturationPixels: 42,
          alphaPixels: 120,
          key: "1|normal|400|24|system-ui|rgba|👩‍💻",
          width: 24,
          height: 24,
        },
      },
    };
  }
  if (key === "zwjGrapheme") {
    return { ...base, logicalClusters: 1, visualClusters: 1 };
  }
  if (key === "bidiLayout") {
    return {
      ...base,
      logicalClusters: ["A", "B", "C", " ", "א", "ב", "ג"],
      visualClusters: ["A", "B", "C", " ", "ג", "ב", "א"],
    };
  }
  if (key === "paragraphWrapping") {
    return { ...base, paragraphLineCount: 3, paragraphRows: 3, darkRows: 8 };
  }
  if (key === "asyncImageSecondFrame") {
    return {
      ...base,
      eventIndexes: {
        placeholder: 4,
        load: 6,
        change: 7,
        repaint: 8,
        ready: 10,
        present: [5, 11],
      },
    };
  }
  return base;
};

const webPlatformObservations = value =>
  Object.fromEntries(webPlatformObservationKeys.map(key => [key, value]));

const skiaObservationKeys = [
  "providerPreflight",
  "fallbackUnavailable",
  "realRendererSmoke",
  "asyncImageSecondFrame",
  "showcaseFirstFrame",
  "markdownFirstFrame",
];

const passedSkiaObservationArgs = skiaObservationKeys.flatMap(key => [
  "--skia-set",
  `${key}=yes`,
]);

const baseEntry = ({
  name,
  host,
  exampleTargets,
  routineCommands,
  runtimeEvidenceCommands,
}) => ({
  name,
  status: "pending",
  host,
  routineCommands,
  runtimeEvidenceCommands,
  exampleTargets,
  windowEvidenceCommand: `.local_repos/window/scripts/record_moui_evidence.sh ${name} --status pending`,
  consumerCommand: "pending",
  observations: { ...pendingObservations },
  artifacts: [`artifacts/platform-evidence/${name}/README.md`],
  notes: ["matching-host runtime evidence pending"],
});

const validManifest = {
  schemaVersion: 2,
  mode: "platform-runtime-evidence",
  generatedBy: "scripts/conformance-check.sh --platform-services",
  windowEvidenceSource: ".local_repos/window/scripts/record_moui_evidence.sh",
  platforms: [
    baseEntry({
      name: "web",
      host: "Web wasm-gc browser host pending",
      routineCommands: [
        "moon test moui/backend/web --target wasm-gc",
        "moon build examples/showcase/web_wasm --target wasm-gc",
        "moon build examples/markdown_editor/web_wasm --target wasm-gc",
      ],
      runtimeEvidenceCommands: [
        "python3 -m http.server 18080 --bind 127.0.0.1",
        "node scripts/record-web-runtime-presentation.mjs --base-url http://127.0.0.1:18080 --cdp-url http://127.0.0.1:9223 --manifest artifacts/conformance/web-runtime-presentation.json --require-passed # opens examples/showcase/web_wasm and examples/markdown_editor/web_wasm",
        "node scripts/record-platform-evidence-manifest.mjs artifacts/conformance/platform-runtime-evidence.json web --web-presentation-manifest artifacts/conformance/web-runtime-presentation.json",
      ],
      exampleTargets: [
        "examples/showcase/web_wasm",
        "examples/markdown_editor/web_wasm",
      ],
    }),
    baseEntry({
      name: "macos",
      host: "macOS Darwin host pending",
      routineCommands: [
        "sh scripts/dev-check.sh --platform-examples-test",
        "moon build examples/showcase/macos_skia --target native",
        "moon build examples/markdown_editor/macos_skia --target native",
      ],
      runtimeEvidenceCommands: [
        "moon run examples/showcase/macos_skia --target native",
        "moon run examples/markdown_editor/macos_skia --target native",
      ],
      exampleTargets: [
        "examples/showcase/macos_skia",
        "examples/markdown_editor/macos_skia",
      ],
    }),
    baseEntry({
      name: "windows",
      host: "Windows MSVC host pending",
      routineCommands: [
        "moon test moui/backend/windows --target native",
        "powershell -ExecutionPolicy Bypass -File .\\scripts\\windows\\build_windows_msvc.ps1 -Package examples/showcase/windows_skia -BuildOnly",
        "powershell -ExecutionPolicy Bypass -File .\\scripts\\windows\\build_windows_msvc.ps1 -Package examples/markdown_editor/windows_skia -BuildOnly",
        "powershell -ExecutionPolicy Bypass -File .\\scripts\\windows\\package_windows_app_msvc.ps1 -Package examples/showcase/windows_skia",
      ],
      runtimeEvidenceCommands: [
        "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }\"",
        "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/markdown_editor/windows_skia --target native }\"",
      ],
      exampleTargets: [
        "examples/showcase/windows_skia",
        "examples/markdown_editor/windows_skia",
      ],
    }),
    baseEntry({
      name: "linux",
      host: "Linux Wayland host pending",
      routineCommands: [
        "sh scripts/dev-check.sh --platform-examples-test",
        "moon build examples/showcase/linux_skia --target native",
        "moon build examples/markdown_editor/linux_skia --target native",
      ],
      runtimeEvidenceCommands: [
        "moon run examples/showcase/linux_skia --target native",
        "moon run examples/markdown_editor/linux_skia --target native",
      ],
      exampleTargets: [
        "examples/showcase/linux_skia",
        "examples/markdown_editor/linux_skia",
      ],
    }),
  ],
};

const writeManifest = name => {
  const path = join(tmp, name);
  writeFileSync(path, JSON.stringify(validManifest, null, 2));
  return path;
};

const writeLegacyManifest = name => {
  const path = join(tmp, name);
  const legacyManifest = {
    ...validManifest,
    schemaVersion: 1,
    platforms: validManifest.platforms.map(entry => ({
      ...entry,
      observations: Object.fromEntries(
        Object.entries(entry.observations).filter(([key]) => key !== "monitorCursor"),
      ),
    })),
  };
  writeFileSync(path, JSON.stringify(legacyManifest, null, 2));
  return path;
};

const webPresentationTarget = ({
  name,
  packagePath,
  path,
  status = "passed",
}) => ({
  name,
  packagePath,
  path,
  url: name === "showcase-web-wasm"
    ? `http://127.0.0.1:18080/${path}?debug=1&section=advanced-rendering`
    : `http://127.0.0.1:18080/${path}?debug=1`,
  status,
  title: name === "showcase-web-wasm"
    ? "MoUI Showcase Wasm GC"
    : "MoUI Markdown Editor Wasm GC",
  statusText: status === "passed" ? "Running" : "Failed",
  bodyFailed: status !== "passed",
  navigatorGpu: status === "passed",
  canvas: {
    count: status === "passed" ? 1 : 0,
    hostWidth: status === "passed" ? 1280 : 0,
    hostHeight: status === "passed" ? 800 : 0,
    canvasWidth: status === "passed" ? 1280 : 0,
    canvasHeight: status === "passed" ? 800 : 0,
    clientWidth: status === "passed" ? 1280 : 0,
    clientHeight: status === "passed" ? 800 : 0,
  },
  runtimeSignals: {
    adapterRequested: status === "passed",
    deviceRequested: status === "passed",
    wasmStarted: status === "passed",
    running: status === "passed",
  },
  screenshot: {
    artifact: `artifacts/conformance/web-runtime-presentation/${name}.png`,
    width: status === "passed" ? 1280 : 0,
    height: status === "passed" ? 800 : 0,
    totalPixels: status === "passed" ? 1024000 : 0,
    contentPixels: status === "passed" ? 50000 : 0,
    distinctColorBuckets: status === "passed" ? 18 : 0,
    transformPixels: {
      required: name === "showcase-web-wasm",
      passed: name === "showcase-web-wasm" && status === "passed",
      hotPinkPixels: name === "showcase-web-wasm" && status === "passed" ? 72 : 0,
      cyanPixels: name === "showcase-web-wasm" && status === "passed" ? 96 : 0,
      goldPixels: name === "showcase-web-wasm" && status === "passed" ? 18 : 0,
      matchedMarkers: name === "showcase-web-wasm" && status === "passed" ? 3 : 0,
    },
    radialGradient: webRendererProof(name, status, "radialGradient"),
    colorEmojiPixels: webRendererProof(name, status, "colorEmojiPixels"),
    zwjGrapheme: webRendererProof(name, status, "zwjGrapheme"),
    bidiLayout: webRendererProof(name, status, "bidiLayout"),
    paragraphWrapping: webRendererProof(name, status, "paragraphWrapping"),
    selectionRects: webRendererProof(name, status, "selectionRects"),
    graphemeEditing: webRendererProof(name, status, "graphemeEditing"),
    imeCandidateAnchor: webRendererProof(name, status, "imeCandidateAnchor"),
    imeCompositionVisual: webRendererProof(name, status, "imeCompositionVisual"),
    asyncImageSecondFrame: webRendererProof(name, status, "asyncImageSecondFrame"),
  },
  evidenceEvents: status === "passed"
    ? [
        { kind: 10, name: "resize" },
        { kind: 23, name: "pointer_down" },
        { kind: 40, name: "key_down" },
        { kind: 42, name: "ime_commit" },
        {
          kind: 94,
          name: "text_color_glyph",
          format: "rgba",
          fontFamily: "system-ui, emoji",
          fontStyle: "normal",
          fontWeight: 400,
          fontSize: 24,
          glyphKey: "1|normal|400|24|system-ui|rgba|👩‍💻",
          glyphWidth: 24,
          glyphHeight: 24,
          highSaturationPixels: 42,
          alphaPixels: 120,
        },
        { kind: 95, name: "text_grapheme_layout" },
        { kind: 96, name: "text_bidi_layout" },
        { kind: 97, name: "text_paragraph_line", lineIndex: 1 },
        { kind: 97, name: "text_paragraph_line", lineIndex: 2 },
        { kind: 97, name: "text_paragraph_line", lineIndex: 3 },
        { kind: 98, name: "image_placeholder_frame" },
        { kind: 100, name: "present_frame", frame: 1 },
        { kind: 90, name: "image_load" },
        { kind: 92, name: "image_resource_change" },
        { kind: 93, name: "image_repaint_request" },
        { kind: 99, name: "image_ready_frame" },
        { kind: 100, name: "present_frame", frame: 2 },
      ]
    : [],
  observations: {
    ...webPresentationObservations(status === "passed" ? "yes" : "no"),
    textInput: name === "markdown-editor-web-wasm" && status === "passed" ? "yes" : "no",
    radialGradient: name === "showcase-web-wasm" && status === "passed" ? "yes" : "no",
    transformPixels: name === "showcase-web-wasm" && status === "passed" ? "yes" : "no",
    colorEmojiPixels: name === "showcase-web-wasm" && status === "passed" ? "yes" : "no",
    zwjGrapheme: name === "showcase-web-wasm" && status === "passed" ? "yes" : "no",
    bidiLayout: name === "showcase-web-wasm" && status === "passed" ? "yes" : "no",
    paragraphWrapping: name === "showcase-web-wasm" && status === "passed" ? "yes" : "no",
    selectionRects: name === "showcase-web-wasm" && status === "passed" ? "yes" : "no",
    graphemeEditing: name === "showcase-web-wasm" && status === "passed" ? "yes" : "no",
    imeCandidateAnchor: name === "showcase-web-wasm" && status === "passed" ? "yes" : "no",
    imeCompositionVisual: name === "showcase-web-wasm" && status === "passed" ? "yes" : "no",
    asyncImageSecondFrame: name === "showcase-web-wasm" && status === "passed" ? "yes" : "no",
  },
  consoleErrors: status === "passed" ? [] : ["No WebGPU adapter is available"],
  notes: status === "passed" ? ["browser evidence captured"] : ["adapter unavailable"],
});

const writeWebPresentationManifest = (name, overallStatus) => {
  const path = join(tmp, name);
  const targetStatus = overallStatus === "passed" ? "passed" : "failed";
  writeFileSync(path, JSON.stringify({
    schemaVersion: 1,
    mode: "web-runtime-presentation",
    generatedBy: "scripts/record-web-runtime-presentation.mjs",
    baseUrl: "http://127.0.0.1:18080",
    cdpUrl: "http://127.0.0.1:9223",
    overallStatus,
    evidenceBoundary:
      "Browser-local WebGPU, wasm app startup, canvas sizing, resize/input event-bridge, target close, Showcase transform-scene pixel markers, and screenshot evidence for the named browser session; this does not prove cross-browser compatibility, deterministic pixels beyond the recorded marker thresholds, or native platform runtime behavior.",
    browser: {
      product: "Chrome/148.0.7778.216",
      userAgent: "Mozilla/5.0 HeadlessChrome/148.0.0.0",
      protocolVersion: "1.3",
    },
    platformObservations: webPlatformObservations(
      overallStatus === "passed" ? "yes" : "no",
    ),
    targets: [
      webPresentationTarget({
        name: "showcase-web-wasm",
        packagePath: "examples/showcase/web_wasm",
        path: "examples/showcase/web_wasm/index.html",
        status: targetStatus,
      }),
      webPresentationTarget({
        name: "markdown-editor-web-wasm",
        packagePath: "examples/markdown_editor/web_wasm",
        path: "examples/markdown_editor/web_wasm/index.html",
        status: targetStatus,
      }),
    ],
  }, null, 2));
  return path;
};

const runRecorder = (path, platform, args, options = {}) =>
  spawnSync(process.execPath, [recorder, path, platform, ...args], {
    encoding: "utf8",
    env: {
      ...withoutGithubEnv(),
      ...(options.env ?? {}),
    },
  });

const expectPass = (label, result) => {
  if (result.status !== 0) {
    console.error(`${label}: expected recorder to pass`);
    console.error(result.stderr);
    process.exit(1);
  }
};

const expectFail = (label, result, expectedMessage) => {
  if (result.status === 0) {
    console.error(`${label}: expected recorder to fail`);
    process.exit(1);
  }
  if (!result.stderr.includes(expectedMessage)) {
    console.error(`${label}: expected stderr to include '${expectedMessage}'`);
    console.error(result.stderr);
    process.exit(1);
  }
};

const passedObservationArgs = Object.keys(pendingObservations).flatMap(key => [
  "--set",
  `${key}=yes`,
]);

const windowsPath = writeManifest("windows-passed.json");
expectPass(
  "record windows passed evidence",
  runRecorder(windowsPath, "windows", [
    "--status",
    "passed",
    "--host",
    "Windows MSVC CI",
    "--window-evidence-command",
    ".local_repos/window/scripts/record_moui_evidence.sh windows --status passed --host 'Windows MSVC CI'",
    "--consumer-command",
    "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }\"",
    ...passedObservationArgs,
    "--artifact",
    "artifacts/platform-evidence/windows/window-smoke.md",
    "--artifact",
    "artifacts/platform-evidence/windows/showcase-run.log",
    "--note",
    "matching-host Windows evidence observed",
    "--provenance-kind",
    "github-actions",
    "--provenance-host",
    "Windows MSVC CI",
    "--provenance-workflow",
    "MoUI CI",
    "--provenance-job",
    "Windows MSVC native smoke",
    "--provenance-run-url",
    "https://github.com/wzzc-dev/MoUI/actions/runs/123456789",
    "--provenance-run-id",
    "123456789",
    "--provenance-runner",
    "windows-2022",
    "--provenance-artifact",
    "artifacts/platform-evidence/windows/window-smoke.md",
    "--provenance-artifact",
    "artifacts/platform-evidence/windows/showcase-run.log",
    "--provenance-note",
    "Windows platform evidence came from a GitHub Actions job",
    "--skia-status",
    "passed",
    ...passedSkiaObservationArgs,
    "--skia-artifact",
    "artifacts/platform-evidence/windows/skia-provider.log",
    "--skia-artifact",
    "artifacts/platform-evidence/windows/showcase-skia-first-frame.log",
    "--skia-artifact",
    "artifacts/platform-evidence/windows/markdown-skia-first-frame.log",
    "--skia-note",
    "matching-host Windows Skia first-frame evidence observed",
    "--skia-provenance-kind",
    "matching-host-artifact",
    "--skia-provenance-host",
    "Windows MSVC CI",
    "--skia-provenance-artifact",
    "artifacts/platform-evidence/windows/skia-provider.log",
    "--skia-provenance-artifact",
    "artifacts/platform-evidence/windows/showcase-skia-first-frame.log",
    "--skia-provenance-artifact",
    "artifacts/platform-evidence/windows/markdown-skia-first-frame.log",
    "--skia-provenance-note",
    "Windows Skia evidence came from matching-host first-frame artifacts",
  ]),
);
const windowsManifest = JSON.parse(readFileSync(windowsPath, "utf8"));
const windowsEntry = windowsManifest.platforms.find(entry => entry.name === "windows");
if (
  windowsEntry.status !== "passed" ||
  windowsEntry.observations.textInput !== "yes" ||
  windowsEntry.observations.monitorCursor !== "yes" ||
  windowsEntry.evidenceProvenance?.kind !== "github-actions" ||
  windowsEntry.skiaEvidence.status !== "passed" ||
  windowsEntry.skiaEvidence.observations.asyncImageSecondFrame !== "yes" ||
  windowsEntry.skiaEvidence.observations.showcaseFirstFrame !== "yes" ||
  windowsEntry.skiaEvidence.evidenceProvenance?.kind !== "matching-host-artifact"
) {
  console.error("record windows passed evidence: manifest was not updated");
  process.exit(1);
}

expectFail(
  "reject mismatched passed host",
  runRecorder(writeManifest("bad-host.json"), "windows", [
    "--status",
    "passed",
    "--host",
    "macOS CI",
    "--consumer-command",
    "moon run examples/showcase/windows_skia --target native",
    ...passedObservationArgs,
  ]),
  "host must name a matching windows host",
);

const missingProvenancePath = writeManifest("missing-provenance-passed.json");
const missingProvenanceBefore = readFileSync(missingProvenancePath, "utf8");
expectFail(
  "reject passed evidence without provenance",
  runRecorder(missingProvenancePath, "windows", [
    "--status",
    "passed",
    "--host",
    "Windows MSVC CI",
    "--window-evidence-command",
    ".local_repos/window/scripts/record_moui_evidence.sh windows --status passed --host 'Windows MSVC CI'",
    "--consumer-command",
    "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }\"",
    ...passedObservationArgs,
    "--artifact",
    "artifacts/platform-evidence/windows/window-smoke.md",
    "--note",
    "missing provenance should be rejected",
    "--skia-status",
    "passed",
    ...passedSkiaObservationArgs,
    "--skia-artifact",
    "artifacts/platform-evidence/windows/skia-provider.log",
    "--skia-note",
    "matching-host Windows Skia first-frame evidence observed",
    "--skia-provenance-kind",
    "matching-host-artifact",
    "--skia-provenance-host",
    "Windows MSVC CI",
    "--skia-provenance-artifact",
    "artifacts/platform-evidence/windows/skia-provider.log",
    "--skia-provenance-note",
    "Skia route provenance is present but platform provenance is missing",
  ]),
  "evidenceProvenance must be recorded when status is passed",
);
if (readFileSync(missingProvenancePath, "utf8") !== missingProvenanceBefore) {
  console.error("reject passed evidence without provenance: recorder left an invalid manifest on disk");
  process.exit(1);
}

const linuxFailedPath = writeManifest("linux-failed.json");
expectPass(
  "record linux failed evidence",
  runRecorder(linuxFailedPath, "linux", [
    "--status",
    "failed",
    "--host",
    "Linux Wayland CI",
    "--consumer-command",
    "moon run examples/showcase/linux_skia --target native",
    "--set",
    "windowOpened=yes",
    "--set",
    "resizeRedraw=no",
    "--set",
    "surface=yes",
    "--artifact",
    "artifacts/platform-evidence/linux/showcase-run.log",
    "--note",
    "resize/redraw failed under test compositor",
  ]),
);
const linuxManifest = JSON.parse(readFileSync(linuxFailedPath, "utf8"));
const linuxEntry = linuxManifest.platforms.find(entry => entry.name === "linux");
if (linuxEntry.status !== "failed" || linuxEntry.observations.resizeRedraw !== "no") {
  console.error("record linux failed evidence: manifest was not updated");
  process.exit(1);
}

const legacyPath = writeLegacyManifest("legacy-v1-migrates.json");
expectPass(
  "migrate legacy platform evidence manifest",
  runRecorder(legacyPath, "linux", [
    "--status",
    "pending",
    "--note",
    "legacy manifest updated after monitor/cursor evidence schema was added",
  ]),
);
const legacyManifest = JSON.parse(readFileSync(legacyPath, "utf8"));
const legacyLinuxEntry = legacyManifest.platforms.find(entry => entry.name === "linux");
if (
  legacyManifest.schemaVersion !== 2 ||
  legacyLinuxEntry.observations.monitorCursor !== "pending" ||
  legacyLinuxEntry.skiaEvidence.status !== "pending" ||
  legacyLinuxEntry.skiaEvidence.observations.asyncImageSecondFrame !== "pending" ||
  legacyLinuxEntry.skiaEvidence.observations.showcaseFirstFrame !== "pending"
) {
  console.error("migrate legacy platform evidence manifest: schema was not upgraded");
  process.exit(1);
}

const linuxSkiaFailedPath = writeManifest("linux-skia-failed.json");
expectPass(
  "record linux failed skia evidence",
  runRecorder(linuxSkiaFailedPath, "linux", [
    "--skia-status",
    "failed",
    "--skia-set",
    "providerPreflight=yes",
    "--skia-set",
    "fallbackUnavailable=yes",
    "--skia-set",
    "realRendererSmoke=no",
    "--skia-artifact",
    "artifacts/platform-evidence/linux/skia-showcase-first-frame.log",
    "--skia-note",
    "Linux Skia first-frame run failed under the matching Wayland compositor",
  ]),
);
const linuxSkiaFailedManifest = JSON.parse(readFileSync(linuxSkiaFailedPath, "utf8"));
const linuxSkiaFailedEntry = linuxSkiaFailedManifest.platforms.find(entry => entry.name === "linux");
if (
  linuxSkiaFailedEntry.skiaEvidence.status !== "failed" ||
  linuxSkiaFailedEntry.skiaEvidence.observations.realRendererSmoke !== "no"
) {
  console.error("record linux failed skia evidence: manifest was not updated");
  process.exit(1);
}

const webFailedPath = writeManifest("web-presentation-failed.json");
expectPass(
  "record failed web presentation evidence",
  runRecorder(webFailedPath, "web", [
    "--web-presentation-manifest",
    writeWebPresentationManifest("failed-web-runtime-presentation.json", "failed"),
  ]),
);
const webFailedManifest = JSON.parse(readFileSync(webFailedPath, "utf8"));
const webFailedEntry = webFailedManifest.platforms.find(entry => entry.name === "web");
if (
  webFailedEntry.status !== "failed" ||
  webFailedEntry.observations.windowOpened !== "no" ||
  webFailedEntry.observations.surface !== "no" ||
  !webFailedEntry.artifacts.includes("artifacts/platform-evidence/web/web-runtime-presentation.json")
) {
  console.error("record failed web presentation evidence: manifest was not updated");
  process.exit(1);
}

const webPassedPath = writeManifest("web-presentation-passed.json");
expectPass(
  "record passed web presentation evidence as passed platform evidence",
  runRecorder(webPassedPath, "web", [
    "--web-presentation-manifest",
    writeWebPresentationManifest("passed-web-runtime-presentation.json", "passed"),
  ]),
);
const webPassedManifest = JSON.parse(readFileSync(webPassedPath, "utf8"));
const webPassedEntry = webPassedManifest.platforms.find(entry => entry.name === "web");
if (
  webPassedEntry.status !== "passed" ||
  webPassedEntry.observations.windowOpened !== "yes" ||
  webPassedEntry.observations.surface !== "yes" ||
  webPassedEntry.observations.cleanShutdown !== "yes" ||
  webPassedEntry.observations.representativeInput !== "yes" ||
  webPassedEntry.observations.monitorCursor !== "pending" ||
  !webPassedEntry.consumerCommand.includes("--require-passed") ||
  webPassedEntry.evidenceProvenance?.kind !== "matching-host-artifact" ||
  webPassedEntry.evidenceProvenance.workflow !== undefined ||
  webPassedEntry.evidenceProvenance.runUrl !== undefined
) {
  console.error("record passed web presentation evidence: manifest should be passed");
  process.exit(1);
}

const webGithubPath = writeManifest("web-presentation-github-passed.json");
expectPass(
  "record passed web presentation evidence with GitHub Actions provenance",
  runRecorder(
    webGithubPath,
    "web",
    [
      "--web-presentation-manifest",
      writeWebPresentationManifest("github-web-runtime-presentation.json", "passed"),
    ],
    {
      env: {
        GITHUB_ACTIONS: "true",
        GITHUB_SERVER_URL: "https://github.com",
        GITHUB_REPOSITORY: "wzzc-dev/MoUI",
        GITHUB_RUN_ID: "123456789",
        GITHUB_WORKFLOW: "MoUI CI",
        GITHUB_JOB: "web-runtime-presentation",
        RUNNER_NAME: "GitHub Actions 1",
      },
    },
  ),
);
const webGithubManifest = JSON.parse(readFileSync(webGithubPath, "utf8"));
const webGithubEntry = webGithubManifest.platforms.find(entry => entry.name === "web");
if (
  webGithubEntry.status !== "passed" ||
  webGithubEntry.evidenceProvenance?.kind !== "github-actions" ||
  webGithubEntry.evidenceProvenance.workflow !== "MoUI CI" ||
  webGithubEntry.evidenceProvenance.job !== "web-runtime-presentation" ||
  webGithubEntry.evidenceProvenance.runId !== "123456789" ||
  webGithubEntry.evidenceProvenance.runUrl !== "https://github.com/wzzc-dev/MoUI/actions/runs/123456789" ||
  webGithubEntry.evidenceProvenance.runner !== "GitHub Actions 1" ||
  !webGithubEntry.evidenceProvenance.artifacts.includes("artifacts/platform-evidence/web/web-runtime-presentation.json")
) {
  console.error("record passed web presentation evidence with GitHub Actions provenance: provenance was not derived");
  process.exit(1);
}

expectFail(
  "reject unknown observation key",
  runRecorder(writeManifest("bad-key.json"), "web", ["--set", "opened=yes"]),
  "Unknown observation key: opened",
);

expectFail(
  "reject web presentation manifest on native platform",
  runRecorder(writeManifest("web-manifest-on-windows.json"), "windows", [
    "--web-presentation-manifest",
    writeWebPresentationManifest("native-platform-web-presentation.json", "failed"),
  ]),
  "can only update the web platform entry",
);

expectFail(
  "reject mixed derived and manual web evidence",
  runRecorder(writeManifest("mixed-web-evidence.json"), "web", [
    "--web-presentation-manifest",
    writeWebPresentationManifest("mixed-web-presentation.json", "failed"),
    "--status",
    "failed",
  ]),
  "derives status, host, consumer command, observations, and artifacts",
);

expectFail(
  "reject skia evidence on web",
  runRecorder(writeManifest("web-skia-evidence.json"), "web", [
    "--skia-status",
    "pending",
  ]),
  "Skia evidence options can only update native Skia platform entries",
);

expectFail(
  "reject unknown skia observation key",
  runRecorder(writeManifest("bad-skia-key.json"), "linux", [
    "--skia-set",
    "firstFrame=yes",
  ]),
  "Unknown Skia observation key: firstFrame",
);

console.log("platform evidence manifest recorder tests: ok");
