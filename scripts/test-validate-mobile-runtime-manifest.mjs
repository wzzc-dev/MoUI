#!/usr/bin/env node

import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import {
  hasMobileResizeTransition,
  hasMobileTextClipboardRoundTrip,
  hasIosApplicationLog,
  iosIdbElementPlan,
  iosIdbInputPlan,
  iosIdbServiceProbePlan,
  iosSimulatorLaunchPid,
  mobileRuntimeStatus,
  parseMobileRendererStatus,
  parseMobileServiceProbePlan,
  parseMobileTestProbeSnapshot,
  rendererBlockFromMobileBuild,
} from "./lib/mobile-runtime-log.mjs";

const tmp = mkdtempSync(join(tmpdir(), "moui-mobile-runtime-manifest-"));
const validator = "scripts/validate-mobile-runtime-manifest.mjs";
const recorder = "scripts/record-mobile-runtime-smoke.mjs";

const baseManifest = (overrides = {}) => ({
  schemaVersion: 1,
  mode: "mobile-runtime-smoke",
  generatedBy: "scripts/record-mobile-runtime-smoke.mjs",
  platform: "ios",
  app: "component_gallery",
  status: "passed",
  build: {
    fallbackSkia: false,
    artifact: "artifacts/ios/component_gallery/ComponentGallery.app",
    command: "scripts/build-mobile-ios-app.sh --app component_gallery",
  },
  artifacts: {
    screenshotBefore: "artifacts/mobile-runtime/ios/component_gallery/screenshot-before.png",
    screenshot: "artifacts/mobile-runtime/ios/component_gallery/screenshot.png",
    log: "artifacts/mobile-runtime/ios/component_gallery/runtime.log",
  },
  screenshot: {
    width: 390,
    height: 844,
    totalPixels: 329160,
    contentPixels: 42000,
    distinctColorBuckets: 20,
  },
  pixelChange: {
    comparable: true,
    changedPixels: 2400,
    changedRatio: 0.007,
  },
  observations: {
    lifecycleAttach: "yes",
    lifecycleDetach: "yes",
    nonblankFirstFrame: "yes",
    resize: "yes",
    representativeInput: "yes",
    scrollInput: "yes",
    cleanShutdown: "yes",
    ime: "yes",
    clipboard: "yes",
    accessibility: "yes",
    accessibilityTree: "yes",
    accessibilityFocus: "yes",
    accessibilityAction: "yes",
    asyncImage: "yes",
    platformViewCreate: "yes",
    platformViewResize: "yes",
    platformViewClip: "yes",
    platformViewEvent: "yes",
    platformViewDispose: "yes",
    hostChannelSuccess: "yes",
    hostChannelError: "yes",
    hostChannelCancel: "yes",
    hostChannelExactlyOnce: "yes",
    hostChannelLateAfterDispose: "yes",
    gpuRecovery: "yes",
    stress: "yes",
    realDeviceSigning: "pending",
  },
  evidenceBoundary: "non-fallback matching-host smoke evidence; fallback builds are packaging only",
  ...overrides,
});

const run = (manifest, args = []) => {
  const path = join(tmp, `${Math.random().toString(16).slice(2)}.json`);
  writeFileSync(path, JSON.stringify(manifest, null, 2));
  return spawnSync("node", [validator, path, ...args], { encoding: "utf8" });
};

const recordWithoutArtifact = (platform, app) => {
  const manifestPath = join(tmp, `${platform}-${app}-recorded.json`);
  const result = spawnSync("node", [
    recorder,
    "--platform", platform,
    "--app", app,
    "--artifact", join(tmp, "missing-artifact"),
    "--manifest", manifestPath,
  ], { encoding: "utf8" });
  return {
    result,
    manifest: result.status === 0
      ? JSON.parse(readFileSync(manifestPath, "utf8"))
      : null,
  };
};

const assert = (condition, message) => {
  if (!condition) {
    console.error(message);
    process.exit(1);
  }
};

let result = run(baseManifest(), ["--require-passed"]);
assert(result.status === 0, `expected valid manifest, got ${result.status}\n${result.stdout}\n${result.stderr}`);

result = run(baseManifest({ build: { fallbackSkia: true, artifact: "x", command: "x" } }), ["--require-passed"]);
assert(result.status !== 0, "fallback manifest must not validate as passed");

result = run(baseManifest({ observations: { ...baseManifest().observations, scrollInput: "pending" } }), ["--require-passed"]);
assert(result.status !== 0, "component_gallery must require scrollInput when passed");

result = run(baseManifest({ app: "counter", observations: { ...baseManifest().observations, scrollInput: "pending" } }), ["--require-passed"]);
assert(result.status === 0, "counter may leave scrollInput pending");

result = run(baseManifest({ platform: "harmonyos", app: "harmonyos_demo", observations: { ...baseManifest().observations, scrollInput: "pending" } }), ["--require-passed"]);
assert(result.status === 0, "HarmonyOS demo may provide passed matching-device evidence");

const galleryRecording = recordWithoutArtifact("ios", "component_gallery");
assert(
  galleryRecording.result.status === 0
    && galleryRecording.manifest?.status === "failed"
    && galleryRecording.manifest?.observations.scrollInput === "no",
  `Component Gallery recorder must require scroll evidence\n${galleryRecording.result.stdout}\n${galleryRecording.result.stderr}`,
);
const counterRecording = recordWithoutArtifact("ios", "counter");
assert(
  counterRecording.result.status === 0
    && counterRecording.manifest?.status === "failed"
    && counterRecording.manifest?.observations.scrollInput === "pending",
  `Counter recorder must not require scroll evidence\n${counterRecording.result.stdout}\n${counterRecording.result.stderr}`,
);

result = run(baseManifest({ pixelChange: { comparable: true, changedPixels: 0, changedRatio: 0 } }), ["--require-passed"]);
assert(result.status !== 0, "input injection without visible pixel change must not pass");

result = run(baseManifest({ observations: { ...baseManifest().observations, ime: "pending" } }), ["--require-passed"]);
assert(result.status !== 0, "passed evidence must include IME observation");

result = run(baseManifest({ observations: {
  ...baseManifest().observations,
  platformViewCreate: "pending",
} }), ["--require-passed"]);
assert(result.status !== 0, "passed evidence must include PlatformView observations");

result = run(baseManifest({ observations: {
  ...baseManifest().observations,
  hostChannelExactlyOnce: "pending",
} }), ["--require-passed"]);
assert(result.status !== 0, "passed evidence must include Host Channel observations");

result = run(baseManifest({ observations: {
  ...baseManifest().observations,
  gpuRecovery: "pending",
} }), ["--require-passed"]);
assert(result.status !== 0, "passed evidence must include GPU recovery observations");

result = run(baseManifest({ status: "failed", screenshot: { width: 0, height: 0, totalPixels: 0, contentPixels: 0, distinctColorBuckets: 0 } }));
assert(result.status === 0, "failed diagnostic manifest should validate without --require-passed");

result = run(baseManifest({ status: "partial", observations: { ...baseManifest().observations, resize: "no" } }));
assert(result.status === 0, "partial evidence manifest should validate without --require-passed");
result = run(baseManifest({ status: "partial" }), ["--require-passed"]);
assert(result.status !== 0, "partial evidence must not satisfy --require-passed");

const completeScreenshot = baseManifest().screenshot;
assert(
  mobileRuntimeStatus(baseManifest().observations, completeScreenshot, true) === "passed",
  "complete observations and screenshot should produce passed status",
);
assert(
  mobileRuntimeStatus(
    { ...baseManifest().observations, resize: "no" },
    completeScreenshot,
    true,
  ) === "partial",
  "useful but incomplete observations should produce partial status",
);
assert(
  mobileRuntimeStatus(
    Object.fromEntries(Object.keys(baseManifest().observations).map(key => [key, "pending"])),
    { width: 0, height: 0, contentPixels: 0, distinctColorBuckets: 0 },
    true,
  ) === "failed",
  "a run with no usable evidence should produce failed status",
);

assert(
  !hasIosApplicationLog(
    "log[12:0] args: eventMessage CONTAINS 'moui-mobile lifecycle detach'",
    "ComponentGallery",
    "moui-mobile lifecycle detach",
  ),
  "iOS log query command must not count as application detach evidence",
);
assert(
  hasIosApplicationLog(
    "ComponentGallery[42:7] moui-mobile lifecycle detach app=component_gallery",
    "ComponentGallery",
    "moui-mobile lifecycle detach",
  ),
  "target iOS application lifecycle log should count as detach evidence",
);
assert(
  iosSimulatorLaunchPid("dev.wzzc.moui.counter: 95720\n") === "95720"
    && iosSimulatorLaunchPid("launch failed") === "",
  "iOS simulator launch PID parsing should isolate the current app process",
);
assert(
  hasMobileResizeTransition([
    "moui-mobile lifecycle attach width=1206 height=2622",
    "moui-mobile resize width=2622 height=1206",
  ].join("\n")),
  "mobile resize evidence should require two distinct physical sizes",
);
assert(
  !hasMobileResizeTransition([
    "moui-mobile lifecycle attach width=1206 height=2622",
    "moui-mobile resize width=1206 height=2622",
  ].join("\n")),
  "a duplicate initial surface callback must not count as resize evidence",
);
assert(
  hasMobileTextClipboardRoundTrip([
    "moui-mobile service clipboard complete operation=write-text accepted=1",
    "moui-mobile service clipboard complete operation=read-text accepted=true",
  ].join("\n"))
    && !hasMobileTextClipboardRoundTrip(
      "moui-mobile service clipboard complete operation=write-text",
    ),
  "mobile clipboard evidence should require system write and read completion",
);
assert(
  !hasMobileTextClipboardRoundTrip([
    "moui-mobile service clipboard complete operation=write-text accepted=1",
    "moui-mobile service clipboard complete operation=read-text accepted=0",
  ].join("\n")),
  "a stale-generation clipboard completion must not count as a round trip",
);
const probeSnapshot = parseMobileTestProbeSnapshot([
  "moui-mobile test-probe snapshot={truncated",
  'moui-mobile test-probe snapshot={"platformViewCreate":1,"platformViewResize":2,"platformViewClip":1,"platformViewEvent":2,"platformViewDispose":1,"hostChannelSuccess":1,"hostChannelError":1,"hostChannelCancel":1,"hostChannelExactlyOnce":1,"hostChannelLateAfterDispose":1,"serviceSmokeFired":1,"serviceSmokeCompleted":1}',
  'moui-mobile test-probe snapshot={"platformViewCreate":2,"platformViewResize":3,"platformViewClip":2,"platformViewEvent":3,"platformViewDispose":1,"hostChannelSuccess":2,"hostChannelError":1,"hostChannelCancel":1,"hostChannelExactlyOnce":1,"hostChannelLateAfterDispose":1,"serviceSmokeFired":1,"serviceSmokeCompleted":1}',
].join("\n"));
assert(
  probeSnapshot?.platformViewCreate === 2
    && probeSnapshot?.platformViewResize === 3
    && probeSnapshot?.hostChannelSuccess === 2
    && probeSnapshot?.hostChannelExactlyOnce === 1,
  "test-probe parser should use the latest complete normalized snapshot",
);
assert(
  parseMobileTestProbeSnapshot(
    'moui-mobile test-probe snapshot={"platformViewCreate":-1}',
  ) === null,
  "test-probe parser should reject incomplete or invalid counters",
);
const semanticsProbePlan = parseMobileServiceProbePlan([
  "moui-mobile service accessibility tree nodes=12",
  "moui-mobile service probe plan textField=120,240 action=180,300 textFieldId=7 actionId=9 density=2.75",
  "moui-mobile service probe plan textField=130,250 action=190,310 textFieldId=7 actionId=9 density=2.75",
].join("\n"));
assert(
  semanticsProbePlan?.textField.x === 130
    && semanticsProbePlan?.textField.y === 250
    && semanticsProbePlan?.action.x === 190
    && semanticsProbePlan?.action.y === 310,
  "semantics service probe plan should prefer the latest textField/action coordinates",
);
assert(
  parseMobileServiceProbePlan("no probe plan") === null,
  "missing semantics service probe plan should not invent coordinates",
);

const idbPlan = iosIdbInputPlan(JSON.stringify([
  { type: "Application", frame: { x: 0, y: 0, width: 402, height: 874 } },
  { type: "Button", role: "AXButton", AXLabel: "+", enabled: true,
    frame: { x: 261, y: 459, width: 100, height: 40 } },
]));
assert(
  idbPlan?.tap.x === 311 && idbPlan?.tap.y === 479,
  "idb input plan should tap the center of the first enabled button",
);
assert(
  idbPlan?.swipe.xStart === 201 && idbPlan?.swipe.yStart === 656
    && idbPlan?.swipe.yEnd === 219,
  "idb input plan should derive a vertical swipe from the application frame",
);
assert(
  iosIdbInputPlan("not-json") === null
    && iosIdbInputPlan(JSON.stringify([{ type: "Button", enabled: false,
      frame: { x: 0, y: 0, width: 10, height: 10 } }])) === null,
  "idb input plan should reject malformed trees and disabled-only controls",
);

const probeTree = JSON.stringify([
  { type: "Application", frame: { x: 0, y: 0, width: 402, height: 874 } },
  { type: "TextField", AXLabel: "Service probe text", enabled: true,
    frame: { x: 16, y: 96, width: 370, height: 40 } },
  { type: "Button", role: "AXButton", AXLabel: "Activate service probe", enabled: true,
    frame: { x: 16, y: 180, width: 220, height: 40 } },
  { type: "Button", role: "AXButton", AXLabel: "Paste", enabled: true,
    frame: { x: 180, y: 60, width: 64, height: 44 } },
]);
const probePlan = iosIdbServiceProbePlan(probeTree);
assert(
  probePlan?.textField.tap.x === 201 && probePlan?.textField.tap.y === 116
    && probePlan?.action.tap.x === 126 && probePlan?.action.tap.y === 200,
  "service probe plan should locate its text field and action by stable labels",
);
assert(
  iosIdbElementPlan(probeTree, ["Paste"])?.tap.x === 212,
  "idb element plan should locate system edit-menu actions by label",
);

const rendererLog = [
  'moui-mobile renderer configure requested=auto ok=1 status={"platform":"ios","requested":"auto","selected":"skia-gpu-native","surfaceRoute":"metal-gpu","gpuAvailable":true,"gpuPromoted":true,"fallbackReason":null}',
  'moui-mobile lifecycle attach app=counter width=1206 height=2622 attached=1',
].join("\n");
const parsedRenderer = parseMobileRendererStatus(rendererLog);
assert(
  parsedRenderer?.requested === "auto"
    && parsedRenderer?.selected === "SkiaGpuNative"
    && parsedRenderer?.surfaceRoute === "metal-gpu"
    && parsedRenderer?.gpuAvailable === true
    && parsedRenderer?.gpuPromoted === true
    && parsedRenderer?.fallbackReason === "",
  "runtime renderer configure status should map into the mobile-runtime renderer block",
);
assert(
  parseMobileRendererStatus("no configure line") === null,
  "missing renderer configure status should not invent a renderer block",
);
const buildRenderer = rendererBlockFromMobileBuild({
  renderer: {
    requested: "auto",
    selected: "skia-raster",
    gpuPromoted: false,
    fallbackReason: "fallback Skia build cannot provide a native GPU route",
  },
});
assert(
  buildRenderer?.selected === "SkiaRasterNative"
    && buildRenderer?.surfaceRoute === "raster"
    && buildRenderer?.gpuPromoted === false,
  "mobile-build.json renderer should normalize to the runtime schema",
);

console.log("mobile runtime manifest validator tests passed");
