#!/usr/bin/env node

import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const tmp = mkdtempSync(join(tmpdir(), "moui-web-renderer-proof-"));
const recorder = "scripts/record-web-renderer-proof-manifest.mjs";
const githubEnvKeys = [
  "GITHUB_ACTIONS",
  "GITHUB_REPOSITORY",
  "GITHUB_RUN_ID",
  "GITHUB_SERVER_URL",
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

const proofKeys = [
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
];

const proofEvidence = {
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

const proof = key => ({
  required: true,
  passed: true,
  evidence: proofEvidence[key],
  matchedMarkers: proofEvidence[key].length,
});

const writeWebManifest = (name, overrides = {}) => {
  const path = join(tmp, `${name}.json`);
  const observations = Object.fromEntries(proofKeys.map(key => [key, "yes"]));
  const screenshot = {
    radialGradient: proof("radialGradient"),
    colorEmojiPixels: {
      ...proof("colorEmojiPixels"),
      passed: true,
      metadata: {
        font: {
          family: "system-ui, emoji",
          source: "browser-canvas",
          textSystem: "webgpu-wasm",
          shaper: "browser-canvas",
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
    zwjGrapheme: proof("zwjGrapheme"),
    bidiLayout: proof("bidiLayout"),
    paragraphWrapping: proof("paragraphWrapping"),
    selectionRects: proof("selectionRects"),
    graphemeEditing: proof("graphemeEditing"),
    imeCandidateAnchor: proof("imeCandidateAnchor"),
    imeCompositionVisual: proof("imeCompositionVisual"),
    asyncImageSecondFrame: proof("asyncImageSecondFrame"),
  };
  const { screenshot: screenshotOverride, ...targetOverrides } = overrides;
  writeFileSync(
    path,
    `${JSON.stringify(
      {
        overallStatus: "passed",
        targets: [
          {
            name: "showcase-web-wasm",
            status: "passed",
            observations,
            screenshot: {
              ...screenshot,
              ...(screenshotOverride ?? {}),
            },
            ...targetOverrides,
          },
        ],
      },
      null,
      2,
    )}\n`,
  );
  return path;
};

const runRecorder = (name, webManifest, extraArgs = []) => {
  const output = join(tmp, "artifacts", "conformance", "renderer-proof", `${name}.json`);
  return {
    output,
    result: spawnSync(
      process.execPath,
      [
        recorder,
        "--web-presentation-manifest",
        webManifest,
        "--output",
        output,
        ...extraArgs,
      ],
      {
        encoding: "utf8",
        env: {
          ...process.env,
          GITHUB_ACTIONS: "true",
          GITHUB_REPOSITORY: "wzzc-dev/moui",
          GITHUB_RUN_ID: "77",
          GITHUB_SERVER_URL: "https://github.com",
          GITHUB_WORKFLOW: "MoUI CI",
          GITHUB_JOB: "web-runtime-presentation",
          RUNNER_NAME: "ubuntu-24.04",
        },
      },
    ),
  };
};

const runLocalRecorder = (name, webManifest, extraArgs = []) => {
  const output = join(tmp, "artifacts", "conformance", "renderer-proof", `${name}.json`);
  return {
    output,
    result: spawnSync(
      process.execPath,
      [
        recorder,
        "--web-presentation-manifest",
        webManifest,
        "--output",
        output,
        ...extraArgs,
      ],
      { encoding: "utf8", env: withoutGithubEnv() },
    ),
  };
};

const passed = runRecorder("passed", writeWebManifest("passed"), ["--require-passed"]);
if (passed.result.status !== 0) {
  console.error("expected passed web renderer proof");
  console.error(passed.result.stdout);
  console.error(passed.result.stderr);
  process.exit(1);
}
const passedManifest = JSON.parse(readFileSync(passed.output, "utf8"));
if (passedManifest.status !== "passed") {
  console.error("expected passed renderer proof manifest");
  process.exit(1);
}
if (
  passedManifest.observations.colorEmojiPixels.metadata.font.textSystem !== "webgpu-wasm" ||
  passedManifest.observations.colorEmojiPixels.metadata.glyph.highSaturationPixels !== 42 ||
  passedManifest.observations.colorEmojiPixels.metadata.glyph.key !==
    "1|normal|400|24|system-ui|rgba|👩‍💻"
) {
  console.error("expected web renderer proof to preserve color emoji metadata");
  process.exit(1);
}

const localComplete = runLocalRecorder("local-complete", writeWebManifest("local-complete"));
if (localComplete.result.status !== 0) {
  console.error("expected complete local web renderer proof to validate as a failed diagnostic");
  console.error(localComplete.result.stdout);
  console.error(localComplete.result.stderr);
  process.exit(1);
}
const localCompleteManifest = JSON.parse(readFileSync(localComplete.output, "utf8"));
if (
  localCompleteManifest.status !== "failed" ||
  localCompleteManifest.provenance.kind !== "matching-host-artifact" ||
  localCompleteManifest.observations.colorEmojiPixels.status !== "passed"
) {
  console.error("complete local web proof should remain a failed renderer-proof diagnostic");
  process.exit(1);
}

const missingZwjManifest = writeWebManifest("missing-zwj", {
  observations: {
    ...Object.fromEntries(proofKeys.map(key => [key, "yes"])),
    zwjGrapheme: "no",
  },
});
const missingZwj = runRecorder("missing-zwj", missingZwjManifest);
if (missingZwj.result.status !== 0) {
  console.error("expected incomplete web renderer proof to validate structurally");
  console.error(missingZwj.result.stdout);
  console.error(missingZwj.result.stderr);
  process.exit(1);
}
const missingManifest = JSON.parse(readFileSync(missingZwj.output, "utf8"));
if (
  missingManifest.status !== "failed" ||
  missingManifest.observations.zwjGrapheme.status !== "failed"
) {
  console.error("missing ZWJ observation should keep web renderer proof failed");
  process.exit(1);
}

const missingRequired = runRecorder("missing-required", missingZwjManifest, ["--require-passed"]);
if (
  missingRequired.result.status === 0 ||
  !missingRequired.result.stderr.includes("status must be passed") ||
  !missingRequired.result.stderr.includes("web renderer proof failed summary:") ||
  !missingRequired.result.stderr.includes("missingProofs=zwjGrapheme")
) {
  console.error("expected --require-passed to reject missing ZWJ web proof");
  console.error(missingRequired.result.stdout);
  console.error(missingRequired.result.stderr);
  process.exit(1);
}

const missingEmojiMetadataManifest = writeWebManifest("missing-emoji-metadata", {
  screenshot: {
    colorEmojiPixels: {
      ...proof("colorEmojiPixels"),
      passed: true,
    },
  },
});
const missingEmojiMetadata = runRecorder("missing-emoji-metadata", missingEmojiMetadataManifest);
if (missingEmojiMetadata.result.status !== 0) {
  console.error("expected missing emoji metadata proof to validate structurally");
  console.error(missingEmojiMetadata.result.stdout);
  console.error(missingEmojiMetadata.result.stderr);
  process.exit(1);
}
const missingEmojiMetadataProof = JSON.parse(readFileSync(missingEmojiMetadata.output, "utf8"));
if (
  missingEmojiMetadataProof.status !== "failed" ||
  missingEmojiMetadataProof.observations.colorEmojiPixels.status !== "failed"
) {
  console.error("missing emoji metadata should keep web renderer proof failed");
  process.exit(1);
}
const missingEmojiMetadataRequired = runRecorder(
  "missing-emoji-metadata-required",
  missingEmojiMetadataManifest,
  ["--require-passed"],
);
if (
  missingEmojiMetadataRequired.result.status === 0 ||
  !missingEmojiMetadataRequired.result.stderr.includes("status must be passed") ||
  !missingEmojiMetadataRequired.result.stderr.includes("web renderer proof failed summary:") ||
  !missingEmojiMetadataRequired.result.stderr.includes("missingProofs=colorEmojiPixels")
) {
  console.error("expected --require-passed to reject missing emoji metadata web proof");
  console.error(missingEmojiMetadataRequired.result.stdout);
  console.error(missingEmojiMetadataRequired.result.stderr);
  process.exit(1);
}

const missingGlyphKeyManifest = writeWebManifest("missing-glyph-key", {
  screenshot: {
    colorEmojiPixels: {
      ...proof("colorEmojiPixels"),
      passed: true,
      metadata: {
        font: {
          family: "system-ui, emoji",
          source: "browser-canvas",
          textSystem: "webgpu-wasm",
          shaper: "browser-canvas",
        },
        glyph: {
          format: "rgba",
          glyphCount: 1,
          clusterCount: 1,
          highSaturationPixels: 42,
          alphaPixels: 120,
          key: "",
          width: 24,
          height: 24,
        },
      },
    },
  },
});
const missingGlyphKey = runRecorder("missing-glyph-key", missingGlyphKeyManifest);
if (missingGlyphKey.result.status !== 0) {
  console.error("expected missing glyph key proof to validate structurally");
  console.error(missingGlyphKey.result.stdout);
  console.error(missingGlyphKey.result.stderr);
  process.exit(1);
}
const missingGlyphKeyProof = JSON.parse(readFileSync(missingGlyphKey.output, "utf8"));
if (
  missingGlyphKeyProof.status !== "failed" ||
  missingGlyphKeyProof.observations.colorEmojiPixels.status !== "failed"
) {
  console.error("missing glyph key should keep web renderer proof failed");
  process.exit(1);
}

console.log("web renderer proof recorder tests: ok");
