#!/usr/bin/env node

import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const tmp = mkdtempSync(join(tmpdir(), "moui-platform-evidence-record-"));
const recorder = "scripts/record-platform-evidence-manifest.mjs";

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
  "targetClosed",
];

const webPresentationObservations = value =>
  Object.fromEntries(webPresentationObservationKeys.map(key => [key, value]));

const webPlatformObservations = value =>
  Object.fromEntries(Object.keys(pendingObservations).map(key => [key, value]));

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
  schemaVersion: 1,
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
        "moon build examples/showcase/macos --target native",
        "moon build examples/markdown_editor/macos --target native",
      ],
      runtimeEvidenceCommands: [
        "moon run examples/showcase/macos --target native",
        "moon run examples/markdown_editor/macos --target native",
      ],
      exampleTargets: [
        "examples/showcase/macos",
        "examples/showcase/macos_skia",
        "examples/markdown_editor/macos",
      ],
    }),
    baseEntry({
      name: "windows",
      host: "Windows MSVC host pending",
      routineCommands: [
        "moon test moui/backend/windows --target native",
        "powershell -ExecutionPolicy Bypass -File .\\scripts\\windows\\build_windows_msvc.ps1 -Package examples/showcase/windows -BuildOnly",
        "powershell -ExecutionPolicy Bypass -File .\\scripts\\windows\\package_windows_app_msvc.ps1 -Package examples/showcase/windows",
      ],
      runtimeEvidenceCommands: [
        "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/showcase/windows --target native }\"",
        "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/markdown_editor/windows --target native }\"",
      ],
      exampleTargets: [
        "examples/showcase/windows",
        "examples/showcase/windows_skia",
        "examples/markdown_editor/windows",
      ],
    }),
    baseEntry({
      name: "linux",
      host: "Linux Wayland host pending",
      routineCommands: [
        "sh scripts/dev-check.sh --platform-examples-test",
        "moon build examples/showcase/linux --target native",
        "moon build examples/showcase/linux_skia --target native",
      ],
      runtimeEvidenceCommands: [
        "moon run examples/showcase/linux --target native",
        "moon run examples/showcase/linux_skia --target native",
      ],
      exampleTargets: [
        "examples/showcase/linux",
        "examples/showcase/linux_cosmic",
        "examples/showcase/linux_skia",
      ],
    }),
  ],
};

const writeManifest = name => {
  const path = join(tmp, name);
  writeFileSync(path, JSON.stringify(validManifest, null, 2));
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
  url: `http://127.0.0.1:18080/${path}?debug=1`,
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
  },
  evidenceEvents: status === "passed"
    ? [
        { kind: 10, name: "resize" },
        { kind: 23, name: "pointer_down" },
        { kind: 40, name: "key_down" },
        { kind: 42, name: "ime_commit" },
      ]
    : [],
  observations: {
    ...webPresentationObservations(status === "passed" ? "yes" : "no"),
    textInput: name === "markdown-editor-web-wasm" && status === "passed" ? "yes" : "no",
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
      "Browser-local WebGPU, wasm app startup, canvas sizing, resize/input event-bridge, target close, and screenshot evidence for the named browser session; this does not prove cross-browser compatibility, deterministic pixels, or native platform runtime behavior.",
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

const runRecorder = (path, platform, args) =>
  spawnSync(process.execPath, [recorder, path, platform, ...args], {
    encoding: "utf8",
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
    "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/showcase/windows --target native }\"",
    ...passedObservationArgs,
    "--artifact",
    "artifacts/platform-evidence/windows/window-smoke.md",
    "--artifact",
    "artifacts/platform-evidence/windows/showcase-run.log",
    "--note",
    "matching-host Windows evidence observed",
  ]),
);
const windowsManifest = JSON.parse(readFileSync(windowsPath, "utf8"));
const windowsEntry = windowsManifest.platforms.find(entry => entry.name === "windows");
if (windowsEntry.status !== "passed" || windowsEntry.observations.textInput !== "yes") {
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
    "moon run examples/showcase/windows --target native",
    ...passedObservationArgs,
  ]),
  "host must name a matching windows host",
);

const linuxFailedPath = writeManifest("linux-failed.json");
expectPass(
  "record linux failed evidence",
  runRecorder(linuxFailedPath, "linux", [
    "--status",
    "failed",
    "--host",
    "Linux Wayland CI",
    "--consumer-command",
    "moon run examples/showcase/linux --target native",
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
  !webPassedEntry.consumerCommand.includes("--require-passed")
) {
  console.error("record passed web presentation evidence: manifest should be passed");
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

console.log("platform evidence manifest recorder tests: ok");
