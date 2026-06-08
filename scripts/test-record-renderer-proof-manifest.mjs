#!/usr/bin/env node

import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const tmp = mkdtempSync(join(tmpdir(), "moui-renderer-proof-record-"));
const recorder = "scripts/record-renderer-proof-manifest.mjs";

const markers = [
  "MoUI renderer proof radialGradient passed center-mid-edge-pixels shader-payload",
  "MoUI renderer proof transformPixels passed pixel-markers",
  [
    "MoUI renderer proof colorEmojiPixels passed high-saturation-pixels glyph-or-raster font-metadata glyph-metadata",
    "MoUI renderer proof colorEmojiPixels metadata font_family=emoji font_source=browser-canvas text_system=webgpu-wasm shaper=browser-canvas glyph_format=rgba glyph_count=1 cluster_count=1 high_saturation_pixels=42 alpha_pixels=120 glyph_key=1|normal|400|24|system-ui|rgba|emoji glyph_width=24 glyph_height=24",
  ].join("\n"),
  "MoUI renderer proof zwjGrapheme passed single-grapheme-cluster no-interior-caret",
  "MoUI renderer proof bidiLayout passed visual-order",
  "MoUI renderer proof paragraphWrapping passed line-metrics later-line-pixels",
  "MoUI renderer proof selectionRects passed selection-rects line-range",
  "MoUI renderer proof graphemeEditing passed grapheme-boundaries edit-actions",
  "MoUI renderer proof imeCandidateAnchor passed candidate-anchor surrounding-text",
  "MoUI renderer proof imeCompositionVisual passed composition-range preedit-pixels",
  "MoUI renderer proof asyncImageSecondFrame passed late-completion repaint-request second-frame-pixels",
];

const runRecorder = (name, logText, extraArgs = [], envOverrides = {}) => {
  const artifactDir = join(tmp, "artifacts", "conformance", "renderer-proof");
  mkdirSync(artifactDir, { recursive: true });
  const logPath = join(artifactDir, `${name}.log`);
  const outputPath = join(artifactDir, `${name}.json`);
  writeFileSync(logPath, `${logText}\n`);
  const result = spawnSync(
    process.execPath,
    [
      recorder,
      "--backend",
      "webgpu-wasm",
      "--platform",
      "web",
      "--artifact-name",
      "moui-web-runtime-presentation",
      "--output",
      outputPath,
      "--log",
      logPath,
      ...extraArgs,
    ],
    {
      encoding: "utf8",
      env: {
        ...process.env,
        GITHUB_ACTIONS: "true",
        GITHUB_REPOSITORY: "wzzc-dev/moui",
        GITHUB_RUN_ID: "42",
        GITHUB_SERVER_URL: "https://github.com",
        GITHUB_WORKFLOW: "MoUI CI",
        GITHUB_JOB: "web-runtime-presentation",
        RUNNER_NAME: "ubuntu-24.04",
        ...envOverrides,
      },
    },
  );
  return { result, outputPath };
};

const runSkiaRecorder = (name, logText, extraArgs = [], envOverrides = {}) => {
  const artifactDir = join(tmp, "artifacts", "conformance", "renderer-proof");
  mkdirSync(artifactDir, { recursive: true });
  const logPath = join(artifactDir, `${name}.log`);
  const outputPath = join(artifactDir, `${name}.json`);
  writeFileSync(logPath, `${logText}\n`);
  const result = spawnSync(
    process.execPath,
    [
      recorder,
      "--backend",
      "skia-native",
      "--platform",
      "macos",
      "--artifact-name",
      "moui-renderer-proof-skia-native-macos",
      "--output",
      outputPath,
      "--log",
      logPath,
      ...extraArgs,
    ],
    {
      encoding: "utf8",
      env: {
        ...process.env,
        GITHUB_ACTIONS: "true",
        GITHUB_REPOSITORY: "wzzc-dev/moui",
        GITHUB_RUN_ID: "43",
        GITHUB_SERVER_URL: "https://github.com",
        GITHUB_WORKFLOW: "MoUI CI",
        GITHUB_JOB: "renderer-proof-native-skia-macos",
        RUNNER_NAME: "macos-15",
        ...envOverrides,
      },
    },
  );
  return { result, outputPath };
};

const skiaMarkers = markers.map(marker => {
  if (marker.includes("MoUI renderer proof colorEmojiPixels passed")) {
    return marker.replace(
      "MoUI renderer proof colorEmojiPixels passed high-saturation-pixels glyph-or-raster font-metadata glyph-metadata",
      "MoUI renderer proof colorEmojiPixels passed high-saturation-pixels glyph-or-raster font-metadata glyph-metadata fallback-request emoji-hint stable-glyph-key",
    );
  }
  if (marker.startsWith("MoUI renderer proof bidiLayout passed")) {
    return "MoUI renderer proof bidiLayout passed engine=skparagraph bidi_visual_order_ready=true visual-order";
  }
  if (marker.startsWith("MoUI renderer proof paragraphWrapping passed")) {
    return "MoUI renderer proof paragraphWrapping passed engine=skparagraph native_paragraph_ready=true line-metrics later-line-pixels";
  }
  if (marker.startsWith("MoUI renderer proof selectionRects passed")) {
    return "MoUI renderer proof selectionRects passed engine=skparagraph selection-rects line-range";
  }
  return marker;
});

const passed = runRecorder("passed", markers.join("\n"), ["--require-passed"]);
if (passed.result.status !== 0) {
  console.error("expected passed proof recording");
  console.error(passed.result.stdout);
  console.error(passed.result.stderr);
  process.exit(1);
}
const passedManifest = JSON.parse(readFileSync(passed.outputPath, "utf8"));
if (
  passedManifest.status !== "passed" ||
  passedManifest.observations.colorEmojiPixels.status !== "passed" ||
  passedManifest.provenance.kind !== "github-actions"
) {
  console.error("passed manifest did not preserve passed observations/provenance");
  process.exit(1);
}

const skiaPassed = runSkiaRecorder(
  "skia-passed",
  skiaMarkers.join("\n"),
  ["--require-passed"],
);
if (skiaPassed.result.status !== 0) {
  console.error("expected passed Skia native SkParagraph proof recording");
  console.error(skiaPassed.result.stdout);
  console.error(skiaPassed.result.stderr);
  process.exit(1);
}
const skiaPassedManifest = JSON.parse(readFileSync(skiaPassed.outputPath, "utf8"));
if (
  skiaPassedManifest.status !== "passed" ||
  skiaPassedManifest.observations.paragraphWrapping.status !== "passed" ||
  !skiaPassedManifest.observations.colorEmojiPixels.evidence.includes("fallback-request") ||
  !skiaPassedManifest.observations.colorEmojiPixels.evidence.includes("stable-glyph-key") ||
  !skiaPassedManifest.observations.paragraphWrapping.evidence.includes("engine=skparagraph") ||
  !skiaPassedManifest.observations.bidiLayout.evidence.includes("bidi_visual_order_ready=true")
) {
  console.error("passed Skia manifest did not preserve SkParagraph/emoji fallback evidence");
  process.exit(1);
}

const skiaMissingEmojiFallback = runSkiaRecorder(
  "skia-missing-emoji-fallback",
  skiaMarkers.join("\n").replace(" fallback-request", ""),
);
if (skiaMissingEmojiFallback.result.status !== 0) {
  console.error("expected missing Skia emoji fallback token proof to validate as failed");
  console.error(skiaMissingEmojiFallback.result.stdout);
  console.error(skiaMissingEmojiFallback.result.stderr);
  process.exit(1);
}
const skiaMissingEmojiFallbackManifest = JSON.parse(
  readFileSync(skiaMissingEmojiFallback.outputPath, "utf8"),
);
if (
  skiaMissingEmojiFallbackManifest.status !== "failed" ||
  skiaMissingEmojiFallbackManifest.observations.colorEmojiPixels.status !== "failed"
) {
  console.error("missing Skia emoji fallback token should keep color emoji proof failed");
  process.exit(1);
}

const skiaMissingEngine = runSkiaRecorder("skia-missing-engine", markers.join("\n"));
if (skiaMissingEngine.result.status !== 0) {
  console.error("expected missing SkParagraph engine proof to validate as failed");
  console.error(skiaMissingEngine.result.stdout);
  console.error(skiaMissingEngine.result.stderr);
  process.exit(1);
}
const skiaMissingEngineManifest = JSON.parse(
  readFileSync(skiaMissingEngine.outputPath, "utf8"),
);
if (
  skiaMissingEngineManifest.status !== "failed" ||
  skiaMissingEngineManifest.observations.paragraphWrapping.status !== "failed" ||
  skiaMissingEngineManifest.observations.bidiLayout.status !== "failed"
) {
  console.error("missing SkParagraph engine token should keep Skia proof failed");
  process.exit(1);
}
if (
  passedManifest.observations.colorEmojiPixels.metadata.font.family !== "emoji" ||
  passedManifest.observations.colorEmojiPixels.metadata.glyph.format !== "rgba" ||
  passedManifest.observations.colorEmojiPixels.metadata.glyph.highSaturationPixels !== 42 ||
  passedManifest.observations.colorEmojiPixels.metadata.glyph.key !==
    "1|normal|400|24|system-ui|rgba|emoji" ||
  passedManifest.observations.colorEmojiPixels.metadata.glyph.width !== 24 ||
  passedManifest.observations.colorEmojiPixels.metadata.glyph.height !== 24
) {
  console.error("passed manifest did not preserve color emoji metadata");
  process.exit(1);
}

const failed = runRecorder("failed", markers.slice(0, -1).join("\n"));
if (failed.result.status !== 0) {
  console.error("expected failed proof manifest to validate structurally without --require-passed");
  console.error(failed.result.stdout);
  console.error(failed.result.stderr);
  process.exit(1);
}
const failedManifest = JSON.parse(readFileSync(failed.outputPath, "utf8"));
if (
  failedManifest.status !== "failed" ||
  failedManifest.observations.asyncImageSecondFrame.status !== "failed"
) {
  console.error("missing async proof marker should keep manifest failed");
  process.exit(1);
}

const missingEmojiMetadataMarkers = markers.map(marker =>
  marker.includes("MoUI renderer proof colorEmojiPixels metadata")
    ? "MoUI renderer proof colorEmojiPixels passed high-saturation-pixels glyph-or-raster font-metadata glyph-metadata"
    : marker,
);
const missingEmojiMetadata = runRecorder(
  "missing-emoji-metadata",
  missingEmojiMetadataMarkers.join("\n"),
);
if (missingEmojiMetadata.result.status !== 0) {
  console.error("expected missing emoji metadata proof to validate as failed");
  console.error(missingEmojiMetadata.result.stdout);
  console.error(missingEmojiMetadata.result.stderr);
  process.exit(1);
}
const missingEmojiMetadataManifest = JSON.parse(
  readFileSync(missingEmojiMetadata.outputPath, "utf8"),
);
if (
  missingEmojiMetadataManifest.status !== "failed" ||
  missingEmojiMetadataManifest.observations.colorEmojiPixels.status !== "failed"
) {
  console.error("missing emoji metadata should keep renderer proof observation failed");
  process.exit(1);
}

const missingEmojiGlyphKeyMarkers = markers.map(marker =>
  marker.includes("MoUI renderer proof colorEmojiPixels metadata")
    ? marker.replace(/ glyph_key=\S+/, "")
    : marker,
);
const missingEmojiGlyphKey = runRecorder(
  "missing-emoji-glyph-key",
  missingEmojiGlyphKeyMarkers.join("\n"),
);
if (missingEmojiGlyphKey.result.status !== 0) {
  console.error("expected missing emoji glyph key proof to validate as failed");
  console.error(missingEmojiGlyphKey.result.stdout);
  console.error(missingEmojiGlyphKey.result.stderr);
  process.exit(1);
}
const missingEmojiGlyphKeyManifest = JSON.parse(
  readFileSync(missingEmojiGlyphKey.outputPath, "utf8"),
);
if (
  missingEmojiGlyphKeyManifest.status !== "failed" ||
  missingEmojiGlyphKeyManifest.observations.colorEmojiPixels.status !== "failed"
) {
  console.error("missing emoji glyph key should keep renderer proof observation failed");
  process.exit(1);
}

const zeroEmojiGlyphWidthMarkers = markers.map(marker =>
  marker.includes("MoUI renderer proof colorEmojiPixels metadata")
    ? marker.replace("glyph_width=24", "glyph_width=0")
    : marker,
);
const zeroEmojiGlyphWidth = runRecorder(
  "zero-emoji-glyph-width",
  zeroEmojiGlyphWidthMarkers.join("\n"),
);
if (zeroEmojiGlyphWidth.result.status !== 0) {
  console.error("expected zero emoji glyph width proof to validate as failed");
  console.error(zeroEmojiGlyphWidth.result.stdout);
  console.error(zeroEmojiGlyphWidth.result.stderr);
  process.exit(1);
}
const zeroEmojiGlyphWidthManifest = JSON.parse(
  readFileSync(zeroEmojiGlyphWidth.outputPath, "utf8"),
);
if (
  zeroEmojiGlyphWidthManifest.status !== "failed" ||
  zeroEmojiGlyphWidthManifest.observations.colorEmojiPixels.status !== "failed"
) {
  console.error("zero emoji glyph width should keep renderer proof observation failed");
  process.exit(1);
}

const zeroEmojiGlyphHeightMarkers = markers.map(marker =>
  marker.includes("MoUI renderer proof colorEmojiPixels metadata")
    ? marker.replace("glyph_height=24", "glyph_height=0")
    : marker,
);
const zeroEmojiGlyphHeight = runRecorder(
  "zero-emoji-glyph-height",
  zeroEmojiGlyphHeightMarkers.join("\n"),
);
if (zeroEmojiGlyphHeight.result.status !== 0) {
  console.error("expected zero emoji glyph height proof to validate as failed");
  console.error(zeroEmojiGlyphHeight.result.stdout);
  console.error(zeroEmojiGlyphHeight.result.stderr);
  process.exit(1);
}
const zeroEmojiGlyphHeightManifest = JSON.parse(
  readFileSync(zeroEmojiGlyphHeight.outputPath, "utf8"),
);
if (
  zeroEmojiGlyphHeightManifest.status !== "failed" ||
  zeroEmojiGlyphHeightManifest.observations.colorEmojiPixels.status !== "failed"
) {
  console.error("zero emoji glyph height should keep renderer proof observation failed");
  process.exit(1);
}

const localComplete = runRecorder("local-complete", markers.join("\n"), [], {
  GITHUB_ACTIONS: "false",
});
if (localComplete.result.status !== 0) {
  console.error("expected complete local proof observations to validate as a failed diagnostic");
  console.error(localComplete.result.stdout);
  console.error(localComplete.result.stderr);
  process.exit(1);
}
const localCompleteManifest = JSON.parse(readFileSync(localComplete.outputPath, "utf8"));
if (
  localCompleteManifest.status !== "failed" ||
  localCompleteManifest.provenance.kind !== "matching-host-artifact" ||
  localCompleteManifest.observations.asyncImageSecondFrame.status !== "passed" ||
  !localCompleteManifest.notes.some(note => note.includes("GitHub Actions provenance"))
) {
  console.error("complete local proof should remain a failed renderer-proof diagnostic");
  process.exit(1);
}

const failedRequired = runRecorder("failed-required", markers.slice(0, -1).join("\n"), [
  "--require-passed",
]);
if (
  failedRequired.result.status === 0 ||
  !failedRequired.result.stderr.includes("status must be passed")
) {
  console.error("expected --require-passed to reject incomplete proof");
  console.error(failedRequired.result.stdout);
  console.error(failedRequired.result.stderr);
  process.exit(1);
}

console.log("renderer proof manifest recorder tests: ok");
