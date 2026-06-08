#!/usr/bin/env node

import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const tmp = mkdtempSync(join(tmpdir(), "moui-web-runtime-presentation-manifest-"));
const validator = "scripts/validate-web-runtime-presentation-manifest.mjs";

const observationKeys = [
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
  "cleanShutdown",
];

const observations = value => Object.fromEntries(observationKeys.map(key => [key, value]));

const platformObservations = value =>
  Object.fromEntries(platformObservationKeys.map(key => [key, value]));

const proof = (name, status, evidence, extra = {}) => ({
  required: name === "showcase-web-wasm",
  passed: name === "showcase-web-wasm" && status === "passed",
  evidence: name === "showcase-web-wasm" && status === "passed" ? evidence : [],
  matchedMarkers: name === "showcase-web-wasm" && status === "passed" ? evidence.length : 0,
  ...(name === "showcase-web-wasm" && status === "passed" ? extra : {}),
});

const target = ({ name, packagePath, path, status = "passed" }) => ({
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
    radialGradient: proof(name, status, ["center-mid-edge-pixels", "shader-payload"]),
    colorEmojiPixels: proof(
      name,
      status,
      ["high-saturation-pixels", "glyph-or-raster", "font-metadata", "glyph-metadata"],
      {
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
      },
    ),
    zwjGrapheme: proof(
      name,
      status,
      ["single-grapheme-cluster", "no-interior-caret"],
      { logicalClusters: 1, visualClusters: 1 },
    ),
    bidiLayout: proof(
      name,
      status,
      ["visual-order"],
      { logicalClusters: ["A", "B", "C", " ", "א", "ב", "ג"], visualClusters: ["A", "B", "C", " ", "ג", "ב", "א"] },
    ),
    paragraphWrapping: proof(
      name,
      status,
      ["line-metrics", "later-line-pixels"],
      { paragraphLineCount: 3, paragraphRows: 3, darkRows: 8 },
    ),
    selectionRects: proof(name, status, ["selection-rects", "line-range"]),
    graphemeEditing: proof(name, status, ["grapheme-boundaries", "edit-actions"]),
    imeCandidateAnchor: proof(name, status, ["candidate-anchor", "surrounding-text"]),
    imeCompositionVisual: proof(name, status, ["composition-range", "preedit-pixels"]),
    asyncImageSecondFrame: proof(name, status, [
      "late-completion",
      "repaint-request",
      "second-frame-pixels",
    ], {
      eventIndexes: {
        placeholder: 4,
        load: 6,
        change: 7,
        repaint: 8,
        ready: 10,
        present: [5, 11],
      },
    }),
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
          text: "👩‍💻",
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
        { kind: 95, name: "text_grapheme_layout", containsZwj: true, singleGraphemeCluster: true, noInteriorCaret: true },
        { kind: 96, name: "text_bidi_layout", visualOrderDiffers: true },
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
    ...observations(status === "passed" ? "yes" : "no"),
    textInput: name === "markdown-editor-web-wasm" && status === "passed" ? "yes" : "no",
    transformPixels: name === "showcase-web-wasm" && status === "passed" ? "yes" : "no",
    radialGradient: name === "showcase-web-wasm" && status === "passed" ? "yes" : "no",
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
  consoleErrors: status === "passed" ? [] : ["Browser WebGPU is required"],
  notes: status === "passed" ? ["browser evidence captured"] : ["navigator.gpu unavailable"],
});

const validManifest = {
  schemaVersion: 1,
  mode: "web-runtime-presentation",
  generatedBy: "scripts/record-web-runtime-presentation.mjs",
  baseUrl: "http://127.0.0.1:18080",
  cdpUrl: "http://127.0.0.1:9223",
  overallStatus: "passed",
  evidenceBoundary:
    "Browser-local WebGPU, wasm app startup, canvas sizing, resize/input event-bridge, target close, and screenshot evidence for the named browser session; this does not prove cross-browser compatibility, deterministic pixels, or native platform runtime behavior.",
  browser: {
    product: "Chrome/148.0.7778.216",
    userAgent: "Mozilla/5.0 HeadlessChrome/148.0.0.0",
    protocolVersion: "1.3",
  },
  platformObservations: platformObservations("yes"),
  targets: [
    target({
      name: "showcase-web-wasm",
      packagePath: "examples/showcase/web_wasm",
      path: "examples/showcase/web_wasm/index.html",
    }),
    target({
      name: "markdown-editor-web-wasm",
      packagePath: "examples/markdown_editor/web_wasm",
      path: "examples/markdown_editor/web_wasm/index.html",
    }),
  ],
};

const writeFixture = (name, manifest) => {
  const path = join(tmp, name);
  writeFileSync(path, JSON.stringify(manifest, null, 2));
  return path;
};

const runValidator = (path, args = []) =>
  spawnSync(process.execPath, [validator, path, ...args], { encoding: "utf8" });

const expectPass = (label, result) => {
  if (result.status !== 0) {
    console.error(`${label}: expected validator to pass`);
    console.error(result.stderr);
    process.exit(1);
  }
};

const expectFail = (label, result, expectedMessage) => {
  if (result.status === 0) {
    console.error(`${label}: expected validator to fail`);
    process.exit(1);
  }
  if (!result.stderr.includes(expectedMessage)) {
    console.error(`${label}: expected stderr to include '${expectedMessage}'`);
    console.error(result.stderr);
    process.exit(1);
  }
};

expectPass(
  "valid web runtime presentation manifest",
  runValidator(writeFixture("valid.json", validManifest)),
);

expectPass(
  "valid web runtime presentation manifest with require-passed",
  runValidator(writeFixture("valid-require.json", validManifest), ["--require-passed"]),
);

expectFail(
  "missing markdown target",
  runValidator(
    writeFixture("missing-markdown.json", {
      ...validManifest,
      targets: validManifest.targets.filter(target => target.name !== "markdown-editor-web-wasm"),
    }),
  ),
  "targets must include 'markdown-editor-web-wasm'",
);

expectFail(
  "passed target with console error",
  runValidator(
    writeFixture("console-error.json", {
      ...validManifest,
      targets: validManifest.targets.map(target =>
        target.name === "showcase-web-wasm"
          ? { ...target, consoleErrors: ["adapter failed"] }
          : target,
      ),
    }),
  ),
  "passed evidence must not contain console errors",
);

expectFail(
  "passed target with blank screenshot",
  runValidator(
    writeFixture("blank-screenshot.json", {
      ...validManifest,
      targets: validManifest.targets.map(target =>
        target.name === "showcase-web-wasm"
          ? {
              ...target,
              screenshot: {
                ...target.screenshot,
                contentPixels: 0,
                distinctColorBuckets: 1,
              },
            }
          : target,
      ),
    }),
  ),
  "passed evidence requires a nonblank screenshot",
);

expectFail(
  "passed showcase target without transform pixels",
  runValidator(
    writeFixture("missing-transform-pixels.json", {
      ...validManifest,
      targets: validManifest.targets.map(target =>
        target.name === "showcase-web-wasm"
          ? {
              ...target,
              screenshot: {
                ...target.screenshot,
                transformPixels: {
                  ...target.screenshot.transformPixels,
                  passed: false,
                  matchedMarkers: 2,
                },
              },
              observations: { ...target.observations, transformPixels: "no" },
            }
          : target,
      ),
    }),
  ),
  "targets[0].observations.transformPixels must be yes for passed evidence",
);

expectFail(
  "failed manifest with require-passed",
  runValidator(
    writeFixture("failed-require.json", {
      ...validManifest,
      overallStatus: "failed",
      targets: validManifest.targets.map(target =>
        target.name === "showcase-web-wasm"
          ? {
              ...target,
              status: "failed",
              statusText: "Failed",
              bodyFailed: true,
              navigatorGpu: false,
              observations: { ...target.observations, webGpuAvailable: "no" },
              consoleErrors: ["No WebGPU adapter is available"],
            }
          : target,
      ),
    }),
    ["--require-passed"],
  ),
  "overallStatus must be passed when --require-passed is used",
);

expectFail(
  "weak evidence boundary",
  runValidator(
    writeFixture("weak-boundary.json", {
      ...validManifest,
      evidenceBoundary: "Browser smoke.",
    }),
  ),
  "evidenceBoundary must include 'WebGPU'",
);

expectFail(
  "passed manifest with failed platform resize evidence",
  runValidator(
    writeFixture("failed-platform-resize.json", {
      ...validManifest,
      platformObservations: {
        ...validManifest.platformObservations,
        resizeRedraw: "no",
      },
    }),
  ),
  "platformObservations.resizeRedraw must be yes when overallStatus is passed",
);

expectFail(
  "missing event bridge evidence",
  runValidator(
    writeFixture("missing-event-bridge.json", {
      ...validManifest,
      targets: validManifest.targets.map(target =>
        target.name === "showcase-web-wasm"
          ? { ...target, observations: { ...target.observations, resizeEvent: "no" } }
          : target,
      ),
    }),
  ),
  "targets[0].observations.resizeEvent must be yes for passed evidence",
);

expectFail(
  "missing color emoji metadata",
  runValidator(
    writeFixture("missing-color-emoji-metadata.json", {
      ...validManifest,
      targets: validManifest.targets.map(target =>
        target.name === "showcase-web-wasm"
          ? {
              ...target,
              screenshot: {
                ...target.screenshot,
                colorEmojiPixels: {
                  ...target.screenshot.colorEmojiPixels,
                  metadata: undefined,
                },
              },
            }
          : target,
      ),
    }),
  ),
  "screenshot.colorEmojiPixels.metadata",
);

expectFail(
  "missing color emoji glyph key",
  runValidator(
    writeFixture("missing-color-emoji-glyph-key.json", {
      ...validManifest,
      targets: validManifest.targets.map(target =>
        target.name === "showcase-web-wasm"
          ? {
              ...target,
              screenshot: {
                ...target.screenshot,
                colorEmojiPixels: {
                  ...target.screenshot.colorEmojiPixels,
                  metadata: {
                    ...target.screenshot.colorEmojiPixels.metadata,
                    glyph: {
                      ...target.screenshot.colorEmojiPixels.metadata.glyph,
                      key: "",
                    },
                  },
                },
              },
            }
          : target,
      ),
    }),
  ),
  "metadata.glyph",
);

expectFail(
  "passed selection proof with weak evidence",
  runValidator(
    writeFixture("weak-selection-proof.json", {
      ...validManifest,
      targets: validManifest.targets.map(target =>
        target.name === "showcase-web-wasm"
          ? {
              ...target,
              screenshot: {
                ...target.screenshot,
                selectionRects: {
                  ...target.screenshot.selectionRects,
                  evidence: ["selection-rects"],
                },
              },
            }
          : target,
      ),
    }),
  ),
  "screenshot.selectionRects.evidence must include 'line-range'",
);

expectFail(
  "passed showcase target with weak async order",
  runValidator(
    writeFixture("weak-async-order.json", {
      ...validManifest,
      targets: validManifest.targets.map(target =>
        target.name === "showcase-web-wasm"
          ? {
              ...target,
              screenshot: {
                ...target.screenshot,
                asyncImageSecondFrame: {
                  ...target.screenshot.asyncImageSecondFrame,
                  eventIndexes: {
                    placeholder: 8,
                    load: 6,
                    change: 7,
                    repaint: 9,
                    ready: 10,
                    present: [5, 11],
                  },
                },
              },
            }
          : target,
      ),
    }),
  ),
  "passed async image proof requires placeholder, late load, repaint, ready second-frame order",
);

expectFail(
  "nonlocal base url",
  runValidator(
    writeFixture("nonlocal-base-url.json", {
      ...validManifest,
      baseUrl: "https://example.com",
    }),
  ),
  "baseUrl must be a local HTTP URL",
);

console.log("web runtime presentation manifest validator tests: ok");
