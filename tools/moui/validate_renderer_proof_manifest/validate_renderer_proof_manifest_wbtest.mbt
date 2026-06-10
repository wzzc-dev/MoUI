///|
let valid_manifest =
  #|{
  #|  "schemaVersion": 1,
  #|  "mode": "renderer-proof",
  #|  "backend": "webgpu-wasm",
  #|  "platform": "web",
  #|  "status": "passed",
  #|  "provenance": {
  #|    "kind": "github-actions",
  #|    "workflow": "MoUI CI",
  #|    "job": "web-runtime-presentation",
  #|    "runId": "123456",
  #|    "runUrl": "https://github.com/wzzc-dev/moui/actions/runs/123456",
  #|    "runner": "ubuntu-24.04",
  #|    "artifactName": "moui-web-runtime-presentation"
  #|  },
  #|  "artifacts": ["artifacts/conformance/renderer-proof/webgpu-wasm-web.json"],
  #|  "observations": {
  #|    "radialGradient": {
  #|      "status": "passed",
  #|      "evidence": ["center-mid-edge-pixels", "shader-payload"],
  #|      "artifacts": ["artifacts/conformance/renderer-proof/radialGradient.log"]
  #|    },
  #|    "transformPixels": {
  #|      "status": "passed",
  #|      "evidence": ["pixel-markers"],
  #|      "artifacts": ["artifacts/conformance/renderer-proof/transformPixels.log"]
  #|    },
  #|    "colorEmojiPixels": {
  #|      "status": "passed",
  #|      "evidence": ["high-saturation-pixels", "glyph-or-raster", "font-metadata", "glyph-metadata"],
  #|      "artifacts": ["artifacts/conformance/renderer-proof/colorEmojiPixels.log"],
  #|      "metadata": {
  #|        "font": {
  #|          "family": "emoji",
  #|          "source": "browser-canvas",
  #|          "textSystem": "webgpu-wasm",
  #|          "shaper": "browser-canvas"
  #|        },
  #|        "glyph": {
  #|          "format": "rgba",
  #|          "glyphCount": 1,
  #|          "clusterCount": 1,
  #|          "key": "browser-canvas|webgpu-wasm|browser-canvas|rgba|emoji",
  #|          "width": 24,
  #|          "height": 24,
  #|          "highSaturationPixels": 42,
  #|          "alphaPixels": 120
  #|        }
  #|      }
  #|    },
  #|    "zwjGrapheme": {
  #|      "status": "passed",
  #|      "evidence": ["single-grapheme-cluster", "no-interior-caret"],
  #|      "artifacts": ["artifacts/conformance/renderer-proof/zwjGrapheme.log"]
  #|    },
  #|    "bidiLayout": {
  #|      "status": "passed",
  #|      "evidence": ["visual-order"],
  #|      "artifacts": ["artifacts/conformance/renderer-proof/bidiLayout.log"]
  #|    },
  #|    "paragraphWrapping": {
  #|      "status": "passed",
  #|      "evidence": ["line-metrics", "later-line-pixels"],
  #|      "artifacts": ["artifacts/conformance/renderer-proof/paragraphWrapping.log"]
  #|    },
  #|    "selectionRects": {
  #|      "status": "passed",
  #|      "evidence": ["selection-rects", "line-range"],
  #|      "artifacts": ["artifacts/conformance/renderer-proof/selectionRects.log"]
  #|    },
  #|    "graphemeEditing": {
  #|      "status": "passed",
  #|      "evidence": ["grapheme-boundaries", "edit-actions"],
  #|      "artifacts": ["artifacts/conformance/renderer-proof/graphemeEditing.log"]
  #|    },
  #|    "imeCandidateAnchor": {
  #|      "status": "passed",
  #|      "evidence": ["candidate-anchor", "surrounding-text"],
  #|      "artifacts": ["artifacts/conformance/renderer-proof/imeCandidateAnchor.log"]
  #|    },
  #|    "imeCompositionVisual": {
  #|      "status": "passed",
  #|      "evidence": ["composition-range", "preedit-pixels"],
  #|      "artifacts": ["artifacts/conformance/renderer-proof/imeCompositionVisual.log"]
  #|    },
  #|    "asyncImageSecondFrame": {
  #|      "status": "passed",
  #|      "evidence": ["late-completion", "repaint-request", "second-frame-pixels"],
  #|      "artifacts": ["artifacts/conformance/renderer-proof/asyncImageSecondFrame.log"]
  #|    }
  #|  }
  #|}

///|
fn skia_manifest() -> String {
  let shaper_metadata =
    #|"shaper": "skshaper",
    #|          "fallbackScriptTag": "und-Zsye",
    #|          "fallbackLanguageTags": ["und-Zsye", "en"],
    #|          "fallbackLanguageTagCount": 2,
    #|          "fallbackRequestLanguageCount": 2
  let glyph_metadata =
    #|"alphaPixels": 120,
    #|          "resolvedMissingGlyphCount": 0,
    #|          "missingGlyphRecoveryReady": true,
    #|          "fallbackRequestCharacter": 128105
  valid_manifest
  .replace(
    old="\"backend\": \"webgpu-wasm\"",
    new="\"backend\": \"skia-native\"",
  )
  .replace(old="\"platform\": \"web\"", new="\"platform\": \"macos\"")
  .replace(
    old="\"evidence\": [\"high-saturation-pixels\", \"glyph-or-raster\", \"font-metadata\", \"glyph-metadata\"]",
    new="\"evidence\": [\"high-saturation-pixels\", \"glyph-or-raster\", \"font-metadata\", \"glyph-metadata\", \"fallback-request\", \"emoji-hint\", \"stable-glyph-key\"]",
  )
  .replace(
    old="\"evidence\": [\"visual-order\"]",
    new="\"evidence\": [\"engine=skparagraph\", \"bidi_visual_order_ready=true\", \"visual-order\"]",
  )
  .replace(
    old="\"evidence\": [\"line-metrics\", \"later-line-pixels\"]",
    new="\"evidence\": [\"engine=skparagraph\", \"native_paragraph_ready=true\", \"line-metrics\", \"later-line-pixels\"]",
  )
  .replace(
    old="\"evidence\": [\"selection-rects\", \"line-range\"]",
    new="\"evidence\": [\"engine=skparagraph\", \"selection-rects\", \"line-range\", \"rect-geometry\", \"hit-test\"]",
  )
  .replace(
    old="\"evidence\": [\"candidate-anchor\", \"surrounding-text\"]",
    new="\"evidence\": [\"candidate-anchor\", \"surrounding-text\", \"grapheme-boundary\", \"utf8-offsets\"]",
  )
  .replace(
    old="\"evidence\": [\"composition-range\", \"preedit-pixels\"]",
    new="\"evidence\": [\"composition-range\", \"composition-cursor\", \"preedit-pixels\"]",
  )
  .replace(
    old="\"source\": \"browser-canvas\"",
    new="\"source\": \"skia-system-fontmgr\"",
  )
  .replace(
    old="\"textSystem\": \"webgpu-wasm\"",
    new="\"textSystem\": \"skia-raster-text-system\"",
  )
  .replace(old="\"shaper\": \"browser-canvas\"", new=shaper_metadata)
  .replace(old="\"glyphCount\": 1", new="\"glyphCount\": 2")
  .replace(
    old="\"key\": \"browser-canvas|webgpu-wasm|browser-canvas|rgba|emoji\"",
    new="\"key\": \"skia-system-fontmgr|skia-raster-text-system|skshaper|script=und-Zsye|langs=2|lang-tags=und-Zsye+en|emoji-u+128105|rgba\"",
  )
  .replace(old="\"width\": 24", new="\"width\": 28")
  .replace(old="\"height\": 24", new="\"height\": 32")
  .replace(old="\"alphaPixels\": 120", new=glyph_metadata)
}

///|
test "accepts valid webgpu wasm manifest" {
  inspect(
    validate_manifest_text(valid_manifest, true, "").is_empty(),
    content="true",
  )
}

///|
test "rejects non github provenance for passed manifest" {
  let manifest = valid_manifest.replace(
    old="\"kind\": \"github-actions\"",
    new="\"kind\": \"matching-host-artifact\"",
  )
  inspect(
    validate_manifest_text(manifest, true, "").contains(
      "passed renderer proof requires github-actions provenance",
    ),
    content="true",
  )
}

///|
test "rejects weak color emoji evidence" {
  let manifest = valid_manifest.replace(
    old="\"evidence\": [\"high-saturation-pixels\", \"glyph-or-raster\", \"font-metadata\", \"glyph-metadata\"]",
    new="\"evidence\": [\"caret-only\", \"high-saturation-pixels\", \"glyph-or-raster\", \"font-metadata\", \"glyph-metadata\"]",
  )
  inspect(
    validate_manifest_text(manifest, true, "").contains(
      "observations.colorEmojiPixels.evidence must not use caret-only, coverage-only, package-only, preflight-only, or heuristic proof",
    ),
    content="true",
  )
}

///|
test "accepts valid skia native manifest" {
  inspect(
    validate_manifest_text(skia_manifest(), true, "").is_empty(),
    content="true",
  )
}

///|
test "rejects skia native missing fallback request token" {
  let manifest = skia_manifest().replace(old=", \"fallback-request\"", new="")
  inspect(
    validate_manifest_text(manifest, true, "").contains(
      "observations.colorEmojiPixels.evidence must include 'fallback-request'",
    ),
    content="true",
  )
}

///|
test "rejects skia native glyph key missing language tags" {
  let manifest = skia_manifest().replace(old="|lang-tags=und-Zsye+en", new="")
  inspect(
    validate_manifest_text(manifest, true, "").contains(
      "observations.colorEmojiPixels.metadata.glyph.key must include 'lang-tags=und-Zsye+en'",
    ),
    content="true",
  )
}
