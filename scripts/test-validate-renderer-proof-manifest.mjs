#!/usr/bin/env node

import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const tmp = mkdtempSync(join(tmpdir(), "moui-renderer-proof-manifest-"));
const validator = "scripts/validate-renderer-proof-manifest.mjs";

const observationEvidence = {
  radialGradient: ["center-mid-edge-pixels", "shader-payload"],
  transformPixels: ["pixel-markers"],
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

const skiaNativeObservationEvidence = {
  ...observationEvidence,
  colorEmojiPixels: [
    "high-saturation-pixels",
    "glyph-or-raster",
    "font-metadata",
    "glyph-metadata",
    "fallback-request",
    "emoji-hint",
    "stable-glyph-key",
  ],
  bidiLayout: ["engine=skparagraph", "bidi_visual_order_ready=true", "visual-order"],
  paragraphWrapping: [
    "engine=skparagraph",
    "native_paragraph_ready=true",
    "line-metrics",
    "later-line-pixels",
  ],
  selectionRects: ["engine=skparagraph", "selection-rects", "line-range", "hit-test"],
};

const colorEmojiMetadata = () => ({
  font: {
    family: "emoji",
    source: "browser-canvas",
    textSystem: "webgpu-wasm",
    shaper: "browser-canvas",
  },
  glyph: {
    format: "rgba",
    glyphCount: 1,
    clusterCount: 1,
    key: "1|normal|400|24|system-ui|rgba|emoji",
    width: 24,
    height: 24,
    highSaturationPixels: 42,
    alphaPixels: 120,
  },
});

const skiaColorEmojiMetadata = () => ({
  font: {
    family: "emoji",
    source: "skia-system-fontmgr",
    textSystem: "skia-raster-text-system",
    shaper: "skshaper",
    fallbackScriptTag: "und-Zsye",
    fallbackLanguageTagCount: 2,
    fallbackRequestLanguageCount: 2,
  },
  glyph: {
    format: "rgba",
    glyphCount: 2,
    clusterCount: 1,
    key: "skia-system-fontmgr|skia-raster-text-system|skshaper|script=und-Zsye|langs=2|emoji-u+128105|rgba",
    width: 28,
    height: 32,
    highSaturationPixels: 42,
    alphaPixels: 120,
    resolvedMissingGlyphCount: 0,
    missingGlyphRecoveryReady: true,
  },
});

const observations = (
  status = "passed",
  evidenceMap = observationEvidence,
  metadata = colorEmojiMetadata(),
) => {
  const entries = Object.fromEntries(
    Object.entries(evidenceMap).map(([key, evidence]) => [
      key,
      {
        status,
        evidence,
        artifacts: [`artifacts/conformance/renderer-proof/${key}.log`],
      },
    ]),
  );
  entries.colorEmojiPixels.metadata = metadata;
  return entries;
};

const manifest = overrides => ({
  schemaVersion: 1,
  mode: "renderer-proof",
  backend: "webgpu-wasm",
  platform: "web",
  status: "passed",
  provenance: {
    kind: "github-actions",
    workflow: "MoUI CI",
    job: "web-runtime-presentation",
    runId: "123456",
    runUrl: "https://github.com/wzzc-dev/moui/actions/runs/123456",
    runner: "ubuntu-24.04",
    artifactName: "moui-web-runtime-presentation",
  },
  artifacts: ["artifacts/conformance/renderer-proof/webgpu-wasm-web.json"],
  observations: observations(),
  ...overrides,
});

const skiaNativeManifest = overrides => manifest({
  backend: "skia-native",
  platform: "macos",
  artifacts: ["artifacts/conformance/renderer-proof/skia-native-macos.json"],
  observations: observations(
    "passed",
    skiaNativeObservationEvidence,
    skiaColorEmojiMetadata(),
  ),
  ...overrides,
});

const writeFixture = (name, value) => {
  const path = join(tmp, name);
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
  return path;
};

const run = (name, value, args = []) => {
  const path = writeFixture(name, value);
  return spawnSync(process.execPath, [validator, path, ...args], {
    encoding: "utf8",
  });
};

const expectPass = (label, result) => {
  if (result.status !== 0) {
    console.error(`${label}: expected pass`);
    console.error(result.stdout);
    console.error(result.stderr);
    process.exit(1);
  }
};

const expectFail = (label, result, message) => {
  if (result.status === 0 || !result.stderr.includes(message)) {
    console.error(`${label}: expected failure containing '${message}'`);
    console.error(result.stdout);
    console.error(result.stderr);
    process.exit(1);
  }
};

expectPass("valid passed manifest", run("valid.json", manifest(), ["--require-passed"]));

expectFail(
  "missing github provenance",
  run(
    "local-provenance.json",
    manifest({
      provenance: {
        ...manifest().provenance,
        kind: "matching-host-artifact",
      },
    }),
    ["--require-passed"],
  ),
  "passed renderer proof requires github-actions provenance",
);

expectFail(
  "caret-only emoji proof",
  run(
    "caret-only.json",
    manifest({
      observations: {
        ...observations(),
        colorEmojiPixels: {
          status: "passed",
          evidence: [
            "caret-only",
            "high-saturation-pixels",
            "glyph-or-raster",
            "font-metadata",
            "glyph-metadata",
          ],
          artifacts: ["artifacts/conformance/renderer-proof/emoji.log"],
          metadata: colorEmojiMetadata(),
        },
      },
    }),
    ["--require-passed"],
  ),
  "must not use caret-only, coverage-only, package-only, preflight-only, or heuristic proof",
);

expectFail(
  "package-only ime proof",
  run(
    "package-only-ime.json",
    manifest({
      observations: {
        ...observations(),
        imeCandidateAnchor: {
          status: "passed",
          evidence: ["package-only", "candidate-anchor", "surrounding-text"],
          artifacts: ["artifacts/conformance/renderer-proof/ime-anchor.log"],
        },
      },
    }),
    ["--require-passed"],
  ),
  "must not use caret-only, coverage-only, package-only, preflight-only, or heuristic proof",
);

expectPass(
  "valid skia native SkParagraph proof",
  run("valid-skia-native.json", skiaNativeManifest(), ["--require-passed"]),
);

expectFail(
  "skia native paragraph proof rejects missing SkParagraph engine token",
  run(
    "skia-native-missing-engine.json",
    skiaNativeManifest({
      observations: {
        ...observations(
          "passed",
          skiaNativeObservationEvidence,
          skiaColorEmojiMetadata(),
        ),
        paragraphWrapping: {
          status: "passed",
          evidence: ["line-metrics", "later-line-pixels"],
          artifacts: ["artifacts/conformance/renderer-proof/paragraph.log"],
        },
      },
    }),
    ["--require-passed"],
  ),
  "must include 'engine=skparagraph'",
);

expectFail(
  "skia native color emoji proof rejects missing fallback request token",
  run(
    "skia-native-missing-emoji-fallback-request.json",
    skiaNativeManifest({
      observations: {
        ...observations(
          "passed",
          skiaNativeObservationEvidence,
          skiaColorEmojiMetadata(),
        ),
        colorEmojiPixels: {
          status: "passed",
          evidence: observationEvidence.colorEmojiPixels,
          artifacts: ["artifacts/conformance/renderer-proof/emoji.log"],
          metadata: skiaColorEmojiMetadata(),
        },
      },
    }),
    ["--require-passed"],
  ),
  "must include 'fallback-request'",
);

expectFail(
  "skia native color emoji proof rejects missing fallback script metadata",
  run(
    "skia-native-missing-fallback-script.json",
    skiaNativeManifest({
      observations: {
        ...observations(
          "passed",
          skiaNativeObservationEvidence,
          skiaColorEmojiMetadata(),
        ),
        colorEmojiPixels: {
          status: "passed",
          evidence: skiaNativeObservationEvidence.colorEmojiPixels,
          artifacts: ["artifacts/conformance/renderer-proof/emoji.log"],
          metadata: {
            ...skiaColorEmojiMetadata(),
            font: {
              ...skiaColorEmojiMetadata().font,
              fallbackScriptTag: "",
            },
          },
        },
      },
    }),
    ["--require-passed"],
  ),
  "metadata.font.fallbackScriptTag must be a non-empty string",
);

expectFail(
  "skia native color emoji proof rejects mismatched fallback language counts",
  run(
    "skia-native-mismatched-language-count.json",
    skiaNativeManifest({
      observations: {
        ...observations(
          "passed",
          skiaNativeObservationEvidence,
          skiaColorEmojiMetadata(),
        ),
        colorEmojiPixels: {
          status: "passed",
          evidence: skiaNativeObservationEvidence.colorEmojiPixels,
          artifacts: ["artifacts/conformance/renderer-proof/emoji.log"],
          metadata: {
            ...skiaColorEmojiMetadata(),
            font: {
              ...skiaColorEmojiMetadata().font,
              fallbackRequestLanguageCount: 1,
            },
          },
        },
      },
    }),
    ["--require-passed"],
  ),
  "metadata.font.fallbackRequestLanguageCount must match fallbackLanguageTagCount",
);

expectFail(
  "skia native color emoji proof rejects missing glyph recovery audit",
  run(
    "skia-native-missing-glyph-recovery.json",
    skiaNativeManifest({
      observations: {
        ...observations(
          "passed",
          skiaNativeObservationEvidence,
          skiaColorEmojiMetadata(),
        ),
        colorEmojiPixels: {
          status: "passed",
          evidence: skiaNativeObservationEvidence.colorEmojiPixels,
          artifacts: ["artifacts/conformance/renderer-proof/emoji.log"],
          metadata: {
            ...skiaColorEmojiMetadata(),
            glyph: {
              ...skiaColorEmojiMetadata().glyph,
              missingGlyphRecoveryReady: false,
            },
          },
        },
      },
    }),
    ["--require-passed"],
  ),
  "metadata.glyph.missingGlyphRecoveryReady must be true",
);

expectFail(
  "skia native color emoji proof rejects glyph key without fallback script",
  run(
    "skia-native-glyph-key-missing-script.json",
    skiaNativeManifest({
      observations: {
        ...observations(
          "passed",
          skiaNativeObservationEvidence,
          skiaColorEmojiMetadata(),
        ),
        colorEmojiPixels: {
          status: "passed",
          evidence: skiaNativeObservationEvidence.colorEmojiPixels,
          artifacts: ["artifacts/conformance/renderer-proof/emoji.log"],
          metadata: {
            ...skiaColorEmojiMetadata(),
            glyph: {
              ...skiaColorEmojiMetadata().glyph,
              key: "skia-system-fontmgr|skia-raster-text-system|skshaper|script=und|langs=2|emoji-u+128105|rgba",
            },
          },
        },
      },
    }),
    ["--require-passed"],
  ),
  "metadata.glyph.key must include 'script=und-Zsye'",
);

expectFail(
  "skia native selection proof rejects missing hit-test token",
  run(
    "skia-native-missing-hit-test.json",
    skiaNativeManifest({
      observations: {
        ...observations(
          "passed",
          skiaNativeObservationEvidence,
          skiaColorEmojiMetadata(),
        ),
        selectionRects: {
          status: "passed",
          evidence: ["engine=skparagraph", "selection-rects", "line-range"],
          artifacts: ["artifacts/conformance/renderer-proof/selection.log"],
        },
      },
    }),
    ["--require-passed"],
  ),
  "must include 'hit-test'",
);

expectFail(
  "missing emoji metadata",
  run(
    "missing-emoji-metadata.json",
    manifest({
      observations: {
        ...observations(),
        colorEmojiPixels: {
          status: "passed",
          evidence: observationEvidence.colorEmojiPixels,
          artifacts: ["artifacts/conformance/renderer-proof/emoji.log"],
        },
      },
    }),
    ["--require-passed"],
  ),
  "observations.colorEmojiPixels.metadata must be an object",
);

expectFail(
  "weak emoji metadata",
  run(
    "weak-emoji-metadata.json",
    manifest({
      observations: {
        ...observations(),
        colorEmojiPixels: {
          status: "passed",
          evidence: observationEvidence.colorEmojiPixels,
          artifacts: ["artifacts/conformance/renderer-proof/emoji.log"],
          metadata: {
            ...colorEmojiMetadata(),
            glyph: {
              ...colorEmojiMetadata().glyph,
              highSaturationPixels: 4,
            },
          },
        },
      },
    }),
    ["--require-passed"],
  ),
  "metadata.glyph.highSaturationPixels must be at least 8",
);

expectFail(
  "missing emoji glyph key",
  run(
    "missing-emoji-glyph-key.json",
    manifest({
      observations: {
        ...observations(),
        colorEmojiPixels: {
          status: "passed",
          evidence: observationEvidence.colorEmojiPixels,
          artifacts: ["artifacts/conformance/renderer-proof/emoji.log"],
          metadata: {
            ...colorEmojiMetadata(),
            glyph: {
              ...colorEmojiMetadata().glyph,
              key: "",
            },
          },
        },
      },
    }),
    ["--require-passed"],
  ),
  "metadata.glyph.key must be a non-empty string",
);

expectFail(
  "zero emoji glyph width",
  run(
    "zero-emoji-glyph-width.json",
    manifest({
      observations: {
        ...observations(),
        colorEmojiPixels: {
          status: "passed",
          evidence: observationEvidence.colorEmojiPixels,
          artifacts: ["artifacts/conformance/renderer-proof/emoji.log"],
          metadata: {
            ...colorEmojiMetadata(),
            glyph: {
              ...colorEmojiMetadata().glyph,
              width: 0,
            },
          },
        },
      },
    }),
    ["--require-passed"],
  ),
  "metadata.glyph.width must be greater than 0",
);

expectFail(
  "zero emoji glyph height",
  run(
    "zero-emoji-glyph-height.json",
    manifest({
      observations: {
        ...observations(),
        colorEmojiPixels: {
          status: "passed",
          evidence: observationEvidence.colorEmojiPixels,
          artifacts: ["artifacts/conformance/renderer-proof/emoji.log"],
          metadata: {
            ...colorEmojiMetadata(),
            glyph: {
              ...colorEmojiMetadata().glyph,
              height: 0,
            },
          },
        },
      },
    }),
    ["--require-passed"],
  ),
  "metadata.glyph.height must be greater than 0",
);

expectFail(
  "missing async second-frame proof",
  run(
    "missing-async-token.json",
    manifest({
      observations: {
        ...observations(),
        asyncImageSecondFrame: {
          status: "passed",
          evidence: ["late-completion", "repaint-request"],
          artifacts: ["artifacts/conformance/renderer-proof/async.log"],
        },
      },
    }),
    ["--require-passed"],
  ),
  "must include 'second-frame-pixels'",
);

expectFail(
  "missing ime composition visual proof",
  run(
    "missing-ime-composition-token.json",
    manifest({
      observations: {
        ...observations(),
        imeCompositionVisual: {
          status: "passed",
          evidence: ["composition-range"],
          artifacts: ["artifacts/conformance/renderer-proof/ime-composition.log"],
        },
      },
    }),
    ["--require-passed"],
  ),
  "must include 'preedit-pixels'",
);

expectFail(
  "unexpected observation key",
  run(
    "unexpected-key.json",
    manifest({
      observations: {
        ...observations(),
        caretCoverage: {
          status: "passed",
          evidence: ["coverage-only"],
          artifacts: ["artifacts/conformance/renderer-proof/caret.log"],
        },
      },
    }),
  ),
  "observations must contain exactly",
);

const artifactRoot = join(tmp, "uploaded");
mkdirSync(join(artifactRoot, "artifacts", "conformance", "renderer-proof"), { recursive: true });
for (const key of Object.keys(observationEvidence)) {
  writeFileSync(
    join(artifactRoot, "artifacts", "conformance", "renderer-proof", `${key}.log`),
    "artifact\n",
  );
}
writeFileSync(
  join(artifactRoot, "artifacts", "conformance", "renderer-proof", "webgpu-wasm-web.json"),
  "{}\n",
);
expectPass(
  "valid passed manifest with artifact root",
  run("valid-artifacts.json", manifest(), ["--require-passed", "--artifact-root", artifactRoot]),
);

expectFail(
  "missing uploaded artifact",
  run("missing-artifact.json", manifest(), [
    "--require-passed",
    "--artifact-root",
    join(tmp, "missing-artifacts"),
  ]),
  "artifact root does not exist",
);

console.log("renderer proof manifest validator tests: ok");
